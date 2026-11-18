param(
    [Parameter(Mandatory)]
    [ValidateSet('Install', 'Wait', 'Disconnect')]
    [string]$Command
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$StateDir = Join-Path $ENV:RUNNER_TEMP 'gh-remote-access'
$ContinueFile = Join-Path $StateDir 'continue'

$WindowsCommandDir = if ($IsWindows) { Join-Path $ENV:ProgramData 'ssh/gh-remote-access' }

# Command for SSH sessions to release the waiting job. It must be on the PATH of SSH sessions.
$ContinueJobCommand = if ($IsWindows) { Join-Path $ENV:SystemRoot 'continue-job.cmd' } else { '/usr/local/bin/continue-job' }

function Get-TailscaleCli {
    $Cli = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($Cli) {
        return $Cli.Source
    }
    if ($IsWindows) {
        $Cli = Join-Path $ENV:ProgramFiles 'Tailscale/tailscale.exe'
        if (Test-Path -LiteralPath $Cli) {
            return $Cli
        }
    }
    return $null
}

function Set-Output {
    param([string]$Name, [string]$Value)
    Add-Content -LiteralPath $ENV:GITHUB_OUTPUT -Value "$Name=$Value"
}

function Get-DefaultHostname {
    $Repository = ($ENV:GITHUB_REPOSITORY -split '/')[-1]
    $Name = "gh-$Repository-$ENV:GITHUB_JOB-$ENV:GITHUB_RUN_ID-$ENV:GITHUB_RUN_ATTEMPT".ToLowerInvariant()
    $Name = $Name -replace '[^a-z0-9-]', '-' -replace '-+', '-'
    if ($Name.Length -gt 63) {
        $Name = $Name.Substring($Name.Length - 63)
    }
    return $Name.Trim('-')
}

function Install-AuthorizedKeysCommand {
    param([string]$Directory, [string]$Tailscale)

    $Script = Join-Path $Directory 'authorized-keys-command.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'authorized-keys-command.ps1') -Destination $Script -Force

    $AllowedUsers = @($ENV:TS_ALLOWED_USERS -split '[,\s]+' | Where-Object { $_ })
    @{
        User = [Environment]::UserName
        AllowedUsers = $AllowedUsers
        Tailscale = $Tailscale
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Directory 'config.json')

    if ($AllowedUsers.Count -gt 0) {
        Write-Output "Allowed tailnet users: $($AllowedUsers -join ', ')" | Out-Host
    } else {
        Write-Output 'Allowed tailnet users: any user permitted to reach port 22 by the tailnet policy' | Out-Host
    }

    $Pwsh = Format-SshdArgument (Get-Command pwsh).Source
    $ScriptPath = Format-SshdArgument $Script
    return "$Pwsh -NoProfile -NonInteractive -File $ScriptPath %C %u %t %k"
}

# Escapes a path for use as an sshd command line argument. sshd requires the command to start with an
# absolute path (a leading quote is rejected), so special characters are escaped instead of quoted.
# Backslashes become forward slashes, which Windows accepts.
function Format-SshdArgument {
    param([string]$Path)
    return ($Path -replace '\\', '/') -replace '([ "''])', '\$1'
}

function Install-OpenSSHServerWindows {
    if (-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
        Write-Output 'Installing OpenSSH server'
        Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Add-WindowsCapability -Online | Out-Null
    }

    $Sshd = Join-Path $ENV:SystemRoot 'System32/OpenSSH/sshd.exe'
    if (-not (Test-Path -LiteralPath $Sshd)) {
        $Sshd = (Get-CimInstance -ClassName Win32_Service -Filter "Name='sshd'").PathName.Trim('"')
    }
    Write-Output "OpenSSH server: $((Get-Item -LiteralPath $Sshd).VersionInfo.ProductVersion)"

    # Windows Server 2025 ships sshd preinstalled but disabled.
    Set-Service -Name sshd -StartupType Manual

    # Starting the service once generates the host keys and the default sshd_config.
    Start-Service -Name sshd
    Stop-Service -Name sshd

    $SshDir = Join-Path $ENV:ProgramData 'ssh'

    # sshd runs the AuthorizedKeysCommand as SYSTEM, so its script and configuration
    # must only be writable by Administrators and SYSTEM.
    $CommandDir = $WindowsCommandDir
    New-Item -ItemType Directory -Force -Path $CommandDir | Out-Null
    icacls.exe $CommandDir /inheritance:r /grant '*S-1-5-32-544:(OI)(CI)F' /grant '*S-1-5-18:(OI)(CI)F' | Out-Null

    $AuthorizedKeysCommand = Install-AuthorizedKeysCommand -Directory $CommandDir `
        -Tailscale (Join-Path $ENV:ProgramFiles 'Tailscale/tailscale.exe')

    # The first occurrence of a setting wins, so prepend to override the defaults.
    $Settings = @(
        'PasswordAuthentication no'
        'KbdInteractiveAuthentication no'
        'PubkeyAuthentication yes'
        "AuthorizedKeysCommand $AuthorizedKeysCommand"
        'AuthorizedKeysCommandUser SYSTEM'
        ''
    ) -join "`n"
    $Config = Join-Path $SshDir 'sshd_config'
    $Content = Get-Content -LiteralPath $Config -Raw
    if (-not $Content.StartsWith($Settings)) {
        Set-Content -LiteralPath $Config -Value ($Settings + $Content) -NoNewline
    }

    & $Sshd -t
    if ($LastExitCode -ne 0) {
        throw 'The generated sshd_config is invalid.'
    }

    New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value (Get-Command pwsh).Source -PropertyType String -Force | Out-Null

    # Allow SSH from the tailnet address ranges only.
    if (-not (Get-NetFirewallRule -Name 'gh-remote-access-ssh' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'gh-remote-access-ssh' -DisplayName 'gh-remote-access SSH' `
            -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow `
            -RemoteAddress @('100.64.0.0/10', 'fd7a:115c:a1e0::/48') | Out-Null
    }

    Start-Service -Name sshd
}

function Install-ContinueJobCommand {
    if ($IsWindows) {
        @(
            '@echo off'
            'rem Installed by gh-remote-access: releases the job waiting for remote access.'
            "type nul > `"$ContinueFile`""
            'echo Released. The job will continue shortly.'
        ) | Set-Content -LiteralPath $ContinueJobCommand
    } else {
        $Quoted = "'" + ($ContinueFile -replace "'", "'\''") + "'"
        @(
            '#!/bin/sh'
            '# Installed by gh-remote-access: releases the job waiting for remote access.'
            '# Users other than the job user cannot write to the state directory, so fall back to sudo.'
            "touch $Quoted 2>/dev/null || sudo -n touch $Quoted || exit 1"
            'echo "Released. The job will continue shortly."'
        ) -join "`n" | sudo -n tee $ContinueJobCommand | Out-Null
        sudo -n chmod 755 $ContinueJobCommand
    }
}

function Invoke-Install {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

    $Hostname = if ($ENV:TS_HOSTNAME) { $ENV:TS_HOSTNAME } else { Get-DefaultHostname }
    $ENV:TS_HOSTNAME = $Hostname
    Set-Output 'hostname' $Hostname

    if ($IsWindows) {
        Set-Output 'args' ''
        Set-Output 'tailscaled-args' ''
        Set-Output 'statedir' ''

        Install-OpenSSHServerWindows
    } else {
        $PSNativeCommandUseErrorActionPreference = $false
        if (Get-Command sudo -ErrorAction SilentlyContinue) {
            sudo -n true 2>$null
        }
        if (-not (Get-Command sudo -ErrorAction SilentlyContinue) -or $LastExitCode -ne 0) {
            throw 'Passwordless sudo is required to run tailscaled.'
        }

        $PSNativeCommandUseErrorActionPreference = $true

        Set-Output 'args' '--ssh'

        # Job containers usually lack a TUN device. Tailscale SSH works without one.
        $Userspace = $IsLinux -and -not (Test-Path -LiteralPath '/dev/net/tun')
        Set-Output 'tailscaled-args' $(if ($Userspace) { '--tun=userspace-networking' } else { '' })

        # Tailscale SSH stores its host keys in the state directory.
        Set-Output 'statedir' (Join-Path $StateDir 'state')
    }

    Install-ContinueJobCommand
}

function Invoke-Wait {
    $Cli = Get-TailscaleCli
    $Status = & $Cli status --json | ConvertFrom-Json
    $DnsName = $Status.Self.DNSName.TrimEnd('.')
    $Address = @($Status.Self.TailscaleIPs)[0]
    $User = [Environment]::UserName

    $Lines = @(
        "Connect: ssh $User@$DnsName"
        "Address: $Address"
        'Release: continue-job'
    )
    $Lines | Write-Output

    if ($ENV:GITHUB_STEP_SUMMARY) {
        @(
            '### Remote access'
            ''
            '```'
            $Lines
            '```'
        ) | Add-Content -LiteralPath $ENV:GITHUB_STEP_SUMMARY
    }

    $Minutes = [int]$ENV:TS_TIMEOUT_MINUTES
    $Deadline = if ($Minutes -gt 0) { (Get-Date).AddMinutes($Minutes) } else { [datetime]::MaxValue }

    Write-Output "Waiting for continue-job to be run$(if ($Minutes -gt 0) { " (timeout $Minutes minutes)" })."

    $NextReport = (Get-Date).AddMinutes(1)
    while (-not (Test-Path -LiteralPath $ContinueFile)) {
        $Now = Get-Date
        if ($Now -ge $Deadline) {
            Write-Output '::notice::Remote access timed out. Continuing the job.'
            return
        }
        if ($Now -ge $NextReport) {
            if ($Minutes -gt 0) {
                Write-Output "Still waiting. $([int][math]::Ceiling(($Deadline - $Now).TotalMinutes)) minute(s) remaining."
            } else {
                Write-Output 'Still waiting.'
            }
            $NextReport = $Now.AddMinutes(1)
        }
        Start-Sleep -Seconds 5
    }

    Write-Output 'Released. Continuing the job.'
}

function Invoke-Disconnect {
    $PSNativeCommandUseErrorActionPreference = $false
    $ErrorActionPreference = 'Continue'

    # Logging out deletes the ephemeral node immediately, ending remote access for the rest of the job.
    # tailscale/github-action stops tailscaled in its own post step at the end of the job.
    $Cli = Get-TailscaleCli
    if ($Cli) {
        if ($IsWindows) {
            & $Cli logout
        } else {
            sudo -n $Cli logout
        }
    }

    if ($IsWindows) {
        Remove-Item -LiteralPath $ContinueJobCommand -ErrorAction SilentlyContinue
    } else {
        sudo -n rm -f $ContinueJobCommand
    }

    if ($IsWindows) {
        Stop-Service -Name sshd -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -Name 'gh-remote-access-ssh' -ErrorAction SilentlyContinue

        $AuthLog = Join-Path $WindowsCommandDir 'auth.log'
        if (Test-Path -LiteralPath $AuthLog) {
            Write-Output '::group::SSH authentication log'
            Get-Content -LiteralPath $AuthLog | Write-Output
            Write-Output '::endgroup::'
            Remove-Item -LiteralPath $AuthLog
        }
    }

    exit 0
}

switch ($Command) {
    'Install' { Invoke-Install }
    'Wait' { Invoke-Wait }
    'Disconnect' { Invoke-Disconnect }
}
