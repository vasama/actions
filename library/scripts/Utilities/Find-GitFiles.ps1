#!/usr/bin/pwsh

param(
	[Parameter(Mandatory)]
	[string[]]$Pattern,

	[string]$Path='.'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Path = Resolve-Path -ErrorAction Stop $Path
$Pathspecs = $Pattern | ForEach-Object { ":(glob)**/$_" }

# The paths are NUL separated to avoid quoting by git:
(git -C $Path ls-files -z -- @Pathspecs) -split "`0" `
	| Where-Object { $_ } `
	| ForEach-Object { "$Path/$_" }
