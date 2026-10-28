#!/usr/bin/pwsh

# Creates a Python virtual environment with the dependencies of the library Python scripts.
# Outputs the path of the virtual environment's Python executable.

param(
	[Parameter(Mandatory)]
	[string]$Path
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($IsWindows) {
	$SystemPython = 'python'
	$Python = "$Path/Scripts/python.exe"
} else {
	$SystemPython = 'python3'
	$Python = "$Path/bin/python"
}

$Requirements = Resolve-Path -ErrorAction Stop "$PSScriptRoot/../Python/requirements.txt"

# Keep the command output out of the script output:
& $SystemPython -m venv $Path | Out-Host
& $Python -m pip install --quiet --disable-pip-version-check -r $Requirements | Out-Host

Write-Output $Python
