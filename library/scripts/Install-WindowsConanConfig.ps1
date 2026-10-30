#!/usr/bin/pwsh

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Generate-HostProfile() {
	Write-Output '[platform_tool_requires]'

	if (!("$(cmake --version)" -match 'cmake version (\d+\.\d+\.\d+)\b')) {
		throw 'Unable to detect CMake version'
	}

	Write-Output "cmake/$($Matches[1])"
}

conan config install (Resolve-Path -ErrorAction Stop "$PSScriptRoot/../conan-windows")

$ProfilesDirectory = "$(conan config home)/profiles"
Generate-HostProfile | Out-File "$ProfilesDirectory/vsm-host"
