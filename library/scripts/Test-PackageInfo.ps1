#!/usr/bin/pwsh

# Validates the package_info.json files tracked in a repository.

param(
	[string]$Path='.',
	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$ValidateScript = Resolve-Path -ErrorAction Stop "$PSScriptRoot/Python/Conan/validate_package_info.py"

$PackageInfoFiles = @(& "$PSScriptRoot/Utilities/Find-GitFiles.ps1" -Path $Path -Pattern 'package_info.json')

if ($WhatIf) {
	Write-Output "python $ValidateScript $PackageInfoFiles"
} else {
	python $ValidateScript @PackageInfoFiles
}
