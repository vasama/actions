#!/usr/bin/pwsh

param(
	[string]$GitHubSourceReference,

	[string]$GitHubIndexRepository,
	[string]$GitHubIndexReference='main',
	[string]$GitHubIndexWorkflow='create-package.yml',

	[string]$PackageName=$null,
	[string]$PackageVersion=$null,
	[string]$PackageBase=$null,

	[string]$ArchiveUrl,
	[string]$ArchiveHash,

	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($PackageName -and $PackageBase) {
	throw 'PackageBase may not be specified together with PackageName'
}

if (!$ArchiveUrl -or !$ArchiveHash) {
	throw 'ArchiveUrl and ArchiveHash must be specified.'
}

if (!$PackageName -or !$PackageVersion) {
	# Deduce package name and version from the git reference:
	# release/package/path/version

	if (!($GitHubSourceReference -match '^refs/(heads|tags)/release/([^/]+(?:/[^/]+)+?)/([^/]+)$')) {
		throw "Invalid release reference: $GitHubSourceReference"
	}

	if (!$PackageName) {
		$PackageName = $Matches[2] -replace '/','.'

		if ($PackageBase) {
			$PackageName = "$PackageBase.$PackageName"
		}
	}

	if (!$PackageVersion) {
		$PackageVersion = $Matches[3]
	}
}

$GhArguments = @(
	'workflow', 'run', $GitHubIndexWorkflow,
	'--repo', $GitHubIndexRepository,
	'--ref', $GitHubIndexReference,
	'-f', "package_name=$PackageName",
	'-f', "package_version=$PackageVersion",
	'-f', "archive_url=$ArchiveUrl",
	'-f', "archive_hash=$ArchiveHash"
)

if ($WhatIf) {
	Write-Output "gh $($GhArguments | ForEach-Object { "'$_'" } | Join-String -Separator ' ')"
} else {
	gh @GhArguments
}
