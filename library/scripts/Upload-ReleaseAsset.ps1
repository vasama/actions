#!/usr/bin/pwsh

param(
	[string]$GitHubRepository,
	[string]$GitHubRepositoryToken,

	[string]$AssetName,
	[string]$AssetPath,

	[switch]$WhatIf=$false
)

$RequestUrl = "https://$ENV:GITHUB_API_URL/repos/$GitHubRepository"
$RequestUrl = "$RequestUrl/releases/$PackageName-$PackageVersion/assets"
$RequestUrl = "$RequestUrl?name=$AssetName"

if ($WhatIf) {
	# Hide the access token:
	$GitHubRepositoryToken = '<access token>'
}

$RequestHeaders = @{}
$RequestHeaders['Accept'] = 'application/vnd.github+json'
$RequestHeaders['Authorization'] = "Bearer $GitHubRepositoryToken"
$RequestHeaders['X-GitHub-Api-Version'] = '2026-03-10'
$RequestHeaders['Content-Type'] = 'application/octet-stream'

if ($WhatIf) {
	$RequestHeaders = [PSCustomObject]$RequestHeaders

	[PSCustomObject]@{
		Url=$RequestUrl;
		Headers=$RequestHeaders;
		Content=$RequestContent;
	}
} else {
	Invoke-WebRequest `
		-Uri $RequestUrl `
		-Method Post `
		-Headers $RequestHeaders `
		-InFile $AssetPath | Out-Null
}
