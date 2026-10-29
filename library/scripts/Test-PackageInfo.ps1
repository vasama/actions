#!/usr/bin/pwsh

# Validates the package_info.json files tracked in a repository.

param(
	[string]$Path='.',
	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$ValidateScript = Resolve-Path -ErrorAction Stop "$PSScriptRoot/Python/Conan/validate_package_info.py"

$Path = Resolve-Path -ErrorAction Stop $Path
$PackageInfoFiles = @(git -C $Path ls-files -- ':(glob)**/package_info.json' | ForEach-Object { "$Path/$_" })

if ($WhatIf) {
	Write-Output "python $ValidateScript $PackageInfoFiles"
} else {
	python $ValidateScript @PackageInfoFiles
}
