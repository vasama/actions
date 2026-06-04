#!/usr/bin/pwsh

param(
	[string]$BaseRef=$null,
	[switch]$TestCurrentCommit=$false,
	[switch]$WhatIf=$false
)

. "$PSScriptRoot/Utilities/Invoke-NativeCommand.ps1"

function Test-GitBranch($BranchName) {
	git show-ref --verify --quiet "refs/heads/$BranchName"
	return $LastExitCode -eq 0
}

function Select-BaseRef {
	foreach ($Candidate in @('develop', 'main', 'master')) {
		if (Test-GitBranch $Candidate) {
			return $Candidate
		}
	}

	throw 'unable to deduce base ref'
}

if ($TestCurrentCommit) {
	if ($BaseRef) {
		throw "base ref may not be specified when testing a commit"
	}

	$TestScript = Resolve-Path "$PSScriptRoot/Test-CxxProject.ps1"

	if ($WhatIf) {
		"$TestScript -Config Release -ConanBuild missing"
	} else {
		& $TestScript -Config Release -ConanBuild missing
	}
} else {
	if (!$BaseRef) {
		$BaseRef = Select-BaseRef
	}

	$PowerShell = & "$PSScriptRoot/Utilities/Find-PowerShell.ps1"
	if ($WhatIf -and (Get-Command 'pwsh').Source -eq $PowerShell) {
		$PowerShell = 'pwsh'
	} else {
		$PowerShell = "'$PowerShell'"
	}

	$ExecScript = "$PowerShell -File '$PSCommandPath' -TestCurrentCommit"

	if ($WhatIf) {
		Write-Output "git rebase $BaseRef --exec `"$ExecScript`""
	} else {
		Invoke-NativeCommand git rebase $BaseRef --exec $ExecScript
	}
}
