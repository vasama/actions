#!/usr/bin/pwsh

param(
	[string]$GitHubSourceRepository,
	[string]$GitHubSourceReference,

	[string]$GitHubIndexRepository,
	[string]$GitHubIndexReference='main',
	[string]$GitHubIndexWorkflow='create-package.yml',
	[string]$GitHubIndexToken,

	[string]$PackagePath=$null,
	[string]$PackageName=$null,
	[string]$PackageVersion=$null,
	[string]$PackageBase=$null,

	[switch]$WhatIf=$false
)

if ($PackageName -and $PackageBase) {
	throw 'PackageBase may not be specified together with PackageName'
}

if (!$PackagePath -or !$PackageVersion) {
	# Deduce package name and version from the git reference:
	# release/package/version

	if ($PackagePath -or $PackageVersion) {
		throw 'PackagePath and PackageVersion must be specified together.'
	}

	if (!($GitHubSourceReference -match '^refs/(heads|tags)/release/([^/]+(?:/[^/]+)+?)/([^/]+)$')) {
		throw "Invalid release reference: $GitHubSourceReference"
	}

	$PackagePath = $Matches[2]
	$PackageVersion = $Matches[3]
}

if (!$PackageName) {
	$PackageName = $PackagePath -replace '\\','/' -replace '/','.'

	if ($PackageBase) {
		$PackageName = "$PackageBase.$PackageName"
	}
}

$WorkflowInputs = @{
	package_path=$PackagePath;
	package_name=$PackageName;
	package_version=$PackageVersion;
	github_repository=$GitHubSourceRepository;
	github_reference=$GitHubSourceReference;
}

$RequestUrl = "https://$ENV:GITHUB_API_URL/repos/$GitHubIndexRepository/actions/workflows/$GitHubIndexWorkflow/dispatches"

if ($WhatIf) {
	# Hide the access token:
	$GitHubIndexToken = '<access token>'
}

$RequestHeaders = @{}
$RequestHeaders['Accept'] = 'application/vnd.github+json'
$RequestHeaders['Authorization'] = "Bearer $GitHubIndexToken"
$RequestHeaders['X-GitHub-Api-Version'] = '2022-11-28'

$RequestContent = ConvertTo-Json @{
	ref=$GitHubIndexReference;
	inputs=$WorkflowInputs;
}

if ($WhatIf) {
	$RequestHeaders = [PSCustomObject]$RequestHeaders

	[PSCustomObject]@{
		Url=$RequestUrl;
		Headers=$RequestHeaders;
		Content=$RequestContent;
	}
} else {
	Invoke-WebRequest -Uri $RequestUrl -Method Post -Headers $RequestHeaders -Body $RequestContent | Out-Null
}
