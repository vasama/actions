#!/usr/bin/pwsh

param(
	[string]$Step=$null,
	[string[]]$Skip=@(),

	[string]$ClangFormatConfig=$null,

	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($Step -and $Skip) {
	throw 'step and skip may not be specified together'
}

# The skipped steps arrive as a single comma separated string when invoked through pwsh -File:
$Skip = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$SkipSet = [System.Collections.Generic.HashSet[string]]::new(
	[string[]]$Skip,
	[StringComparer]::OrdinalIgnoreCase)

function Test-Step($Name) {
	if ($Step) {
		return $Step -eq $Name
	}
	return !$SkipSet.Remove($Name)
}

if (Test-Step 'test-package-info') {
	& "$PSScriptRoot/Test-PackageInfo.ps1" -WhatIf:$WhatIf
}

if (Test-Step 'test-format') {
	& "$PSScriptRoot/Test-CxxFormat.ps1" -Config $ClangFormatConfig -WhatIf:$WhatIf
}

if (Test-Step 'test-project') {
	$TestScript = Resolve-Path -ErrorAction Stop "$PSScriptRoot/Test-CxxProject.ps1"

	$SetupScript = $ENV:VSM_CXX_PROJECT_SETUP
	if ($SetupScript) {
		$SetupScript = Resolve-Path -ErrorAction Stop $SetupScript
	}

	if ($SetupScript) {
		if ($WhatIf) {
			Write-Output $SetupScript
		} else {
			& $SetupScript
		}
	}

	& $TestScript -Config Release -ConanBuild missing -CMakeWarningsAsErrors -WhatIf:$WhatIf
}

if ($SkipSet.Count) {
	throw "unknown skipped steps: $($SkipSet -join ', ')"
}
