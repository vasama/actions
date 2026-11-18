# OpenSSH AuthorizedKeysCommand for Windows, run by sshd as SYSTEM for each offered public key:
#   pwsh -File authorized-keys-command.ps1 %C %u %t %k
#
# Authorizes the offered key if the connecting tailnet peer is a user (not a tagged node) permitted
# by the configuration, and the target account is the job user. Authentication thus relies on the
# Tailscale identity of the peer rather than on the key itself.
#
# Prints nothing to deny, or the offered key in authorized_keys format to accept.

param(
    [string]$Connection,
    [string]$User,
    [string]$KeyType,
    [string]$Key
)

$ErrorActionPreference = 'Stop'

$ConfigDir = $PSScriptRoot
$LogFile = Join-Path $ConfigDir 'auth.log'

function Write-Log {
    param([string]$Message)
    try {
        Add-Content -LiteralPath $LogFile -Value "$((Get-Date).ToString('o')) $Message"
    } catch {
    }
}

# %C expands to: <local address> <local port> <remote address> <remote port>
$Address = ($Connection -split ' ')[2]

try {
    $Config = Get-Content -LiteralPath (Join-Path $ConfigDir 'config.json') -Raw | ConvertFrom-Json

    if ($User -ne $Config.User) {
        Write-Log "deny ${Address}: target user '$User' is not the job user '$($Config.User)'"
        exit 0
    }

    $Json = & $Config.Tailscale whois --json $Address 2>$null
    if ($LastExitCode -ne 0 -or -not $Json) {
        Write-Log "deny ${Address}: not a tailnet peer"
        exit 0
    }
    $WhoIs = $Json | ConvertFrom-Json

    # Filter out nulls: @($null) has one element.
    if (@($WhoIs.Node.Tags | Where-Object { $_ }).Count -gt 0) {
        Write-Log "deny ${Address}: tagged node '$($WhoIs.Node.Name)'"
        exit 0
    }

    $Login = $WhoIs.UserProfile.LoginName
    $AllowedUsers = @($Config.AllowedUsers | Where-Object { $_ })
    if ($AllowedUsers.Count -gt 0 -and $AllowedUsers -notcontains $Login) {
        Write-Log "deny ${Address}: tailnet user '$Login' is not allowed"
        exit 0
    }

    Write-Log "accept ${Address}: tailnet user '$Login' from '$($WhoIs.Node.Name)'"
    Write-Output "$KeyType $Key"
} catch {
    Write-Log "deny ${Address}: $_"
}

exit 0
