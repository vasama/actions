#!/usr/bin/pwsh

[CmdletBinding(PositionalBinding=$false)]
param(
	[switch]$TestCurrentCommit=$false,

	[string]$BaseRef=$null,
	[string]$Script=$null,

	[switch]$WhatIf=$false,

	[Parameter(ValueFromRemainingArguments)]
	[string[]]$ScriptArguments=@()
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Select-BaseRef {
	function Test-Branch($BranchName) {
		$PSNativeCommandUseErrorActionPreference = $false
		git show-ref --verify --quiet "refs/heads/$BranchName"
		return $LastExitCode -eq 0
	}

	foreach ($Candidate in @('develop', 'main', 'master')) {
		if (Test-Branch $Candidate) {
			return $Candidate
		}
	}

	throw 'unable to select default base ref'
}

# git runs the exec command through sh:
function Format-ShellArgument($Argument) {
	return "'$($Argument -replace "'", "'\''")'"
}

$PowerShell = & "$PSScriptRoot/Utilities/Find-PowerShell.ps1"
if ($WhatIf -and (Get-Command 'pwsh').Source -eq $PowerShell) {
	$PowerShell = 'pwsh'
}

if ($TestCurrentCommit) {
	if ($BaseRef -or $Script -or $ScriptArguments) {
		throw 'the script, base ref and script arguments may not be specified when testing a commit'
	}

	if (!$ENV:VSM_GIT_BRANCH_SCRIPT) {
		throw 'VSM_GIT_BRANCH_SCRIPT is not set'
	}

	$Invocation = ConvertFrom-Json $ENV:VSM_GIT_BRANCH_SCRIPT

	if ($WhatIf) {
		Write-Output "$PowerShell -File $($Invocation.Script) $($Invocation.Arguments)"
	} else {
		& $PowerShell -File $Invocation.Script @($Invocation.Arguments)
	}
} else {
	if (!$Script) {
		throw 'the script must be specified'
	}

	$Script = Convert-Path -ErrorAction Stop $Script

	if (!$BaseRef) {
		$BaseRef = Select-BaseRef
	}

	# The script and its arguments are passed through the environment to avoid quoting them for sh:
	$Invocation = @{ Script = $Script; Arguments = $ScriptArguments } | ConvertTo-Json -Compress
	$ExecScript = "$(Format-ShellArgument $PowerShell) -File $(Format-ShellArgument $PSCommandPath) -TestCurrentCommit"

	if ($WhatIf) {
		Write-Output "VSM_GIT_BRANCH_SCRIPT=$(Format-ShellArgument $Invocation)"
		Write-Output "git rebase $BaseRef --exec `"$ExecScript`""
	} else {
		$ENV:VSM_GIT_BRANCH_SCRIPT = $Invocation
		try {
			git rebase $BaseRef --exec $ExecScript
		} finally {
			$ENV:VSM_GIT_BRANCH_SCRIPT = $null
		}
	}
}
