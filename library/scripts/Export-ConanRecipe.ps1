#!/usr/bin/pwsh

param(
	[string]$Remote,

	[string]$PackageName,
	[string]$PackageVersion,
	[string]$PackageUser=$null,
	[string]$PackageChannel=$null,

	[string]$Step=$null
)

$PSNativeCommandUseErrorActionPreference = $true

if (!$Step -or $Step -eq 'conan-export') {
	$RecipeDir = python3 "$PSScriptRoot/Python/Conan/get_recipe_directory.py" `
		--root . `
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

	conan export --version $PackageVersion @ConanArgs $RecipeDir
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
