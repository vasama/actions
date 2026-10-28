#!/usr/bin/pwsh

param(
	[string]$Remote,

	[string]$PackageName,
	[string]$PackageVersion,
	[string]$PackageUser=$null,
	[string]$PackageChannel=$null,

	[string]$IndexPath='.',

	[string]$Step=$null
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($PackageChannel -and !$PackageUser) {
	throw 'PackageChannel requires PackageUser.'
}

$IndexPath = Resolve-Path -ErrorAction Stop $IndexPath

if (!$Step -or $Step -eq 'conan-export') {
	$RecipePath = python "$PSScriptRoot/Python/Conan/get_recipe_directory.py" `
		--index-path $IndexPath `
		--name $PackageName `
		--version $PackageVersion

	$ConanArgs = New-Object System.Collections.Generic.List[System.Object]

	if ($PackageUser) {
		$ConanArgs.Add('--user')
		$ConanArgs.Add($PackageUser)
	}

	if ($PackageChannel) {
		$ConanArgs.Add('--channel')
		$ConanArgs.Add($PackageChannel)
	}

	conan export --version $PackageVersion @ConanArgs $RecipePath
}

if (!$Step -or $Step -eq 'conan-upload') {
	$Reference = "$PackageName/$PackageVersion"

	if ($PackageUser) {
		$Reference = "$Reference@$PackageUser"
		if ($PackageChannel) {
			$Reference = "$Reference/$PackageChannel"
		}
	}

	conan upload --remote $Remote --check $Reference
}
