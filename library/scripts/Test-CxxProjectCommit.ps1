#!/usr/bin/pwsh

param(
	[string]$Step=$null,
	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (!$Step -or $Step -eq 'test-package-info') {
	& "$PSScriptRoot/Test-PackageInfo.ps1" -WhatIf:$WhatIf
}

if (!$Step -or $Step -eq 'test-project') {
	$TestScript = Resolve-Path -ErrorAction Stop "$PSScriptRoot/Test-CxxProject.ps1"

	$SetupScript = $ENV:VSM_CXX_PROJECT_SETUP
	if ($SetupScript) {
		$SetupScript = Resolve-Path -ErrorAction Stop $SetupScript
	}

	if ($WhatIf) {
		if ($SetupScript) {
			Write-Output $SetupScript
		}

		Write-Output "$TestScript -Config Release -ConanBuild missing -CMakeWarningsAsErrors"
	} else {
		if ($SetupScript) {
			& $SetupScript
		}

		& $TestScript -Config Release -ConanBuild missing -CMakeWarningsAsErrors
	}
}
