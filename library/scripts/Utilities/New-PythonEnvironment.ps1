#!/usr/bin/pwsh

param(
	[Parameter(Mandatory)]
	[string]$Path,

	[string]$Requirements = $null
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($IsWindows) {
	$SystemPython = 'python'
	$BinPath = "$Path/Scripts"
} else {
	$SystemPython = 'python3'
	$BinPath = "$Path/bin"
}

if ($Requirements) {
	$Requirements = Resolve-Path -ErrorAction Stop $Requirements
}

& $SystemPython -m venv $Path
. "$BinPath/Activate.ps1"

if ($Requirements) {
	python -m pip install --quiet --disable-pip-version-check -r $Requirements
}
