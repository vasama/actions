#!/usr/bin/pwsh

param(
	[string]$Path='.',
	[string]$Config=$null,
	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (!$Config) {
	$Config = "$PSScriptRoot/../.clang-format"
}
$Config = Resolve-Path -ErrorAction Stop $Config

$SourceFiles = @(& "$PSScriptRoot/Utilities/Find-GitFiles.ps1" -Path $Path -Pattern '*.[hc]', '*.[hc]pp')

if ($SourceFiles) {
	if ($WhatIf) {
		Write-Output "clang-format --style=file:$Config --dry-run --Werror $SourceFiles"
	} else {
		clang-format "--style=file:$Config" --dry-run --Werror @SourceFiles
	}
}
