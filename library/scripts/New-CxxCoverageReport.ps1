#!/usr/bin/pwsh

# Builds and tests the project with Clang source-based coverage instrumentation,
# and writes an HTML coverage report using llvm-cov.

param(
	[string]$Config='Debug',
	[string]$ConanBuild=$null,
	[string]$OutputPath='./coverage',
	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$TestScript = Resolve-Path -ErrorAction Stop "$PSScriptRoot/Test-CxxProject.ps1"
$CoverageProfile = Resolve-Path -ErrorAction Stop "$PSScriptRoot/../conan/coverage"

$TestArguments = @{
	Tool = 'clang'
	Config = $Config
	ConanProfile = @($CoverageProfile.Path)
}

# The build directory may not exist yet:
$BuildDirectory = & $TestScript @TestArguments -Step build-directory
$BuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory, (Get-Location).Path)

$ProfileDirectory = "$BuildDirectory/vsm-coverage"
$ProfileData = "$ProfileDirectory/coverage.profdata"

if ($WhatIf) {
	Write-Output "LLVM_PROFILE_FILE=$ProfileDirectory/%p-%m.profraw"
	& $TestScript @TestArguments -ConanBuild $ConanBuild -WhatIf
	Write-Output "llvm-profdata merge -sparse -o $ProfileData $ProfileDirectory/*.profraw"
	Write-Output "llvm-cov show -format=html -output-dir $OutputPath -instr-profile $ProfileData <test executables>"
	return
}

# Profiles from previous runs would distort the results:
if (Test-Path $ProfileDirectory) {
	Remove-Item -Recurse -Force $ProfileDirectory
}

$ENV:LLVM_PROFILE_FILE = "$ProfileDirectory/%p-%m.profraw"
try {
	& $TestScript @TestArguments -ConanBuild $ConanBuild
} finally {
	$ENV:LLVM_PROFILE_FILE = $null
}

$RawProfiles = @(Get-ChildItem -Path $ProfileDirectory -Filter '*.profraw' | ForEach-Object FullName)
if (!$RawProfiles) {
	throw 'No coverage profiles were produced by the tests.'
}

llvm-profdata merge -sparse -o $ProfileData @RawProfiles

# The coverage mappings are read from the test executables built in the build directory:
$Tests = (ctest --test-dir $BuildDirectory --show-only=json-v1 | ConvertFrom-Json).tests
$PathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$BuildDirectoryPrefix = "$BuildDirectory$([System.IO.Path]::DirectorySeparatorChar)"

$Objects = @($Tests |
	ForEach-Object { if ($_.command) { [System.IO.Path]::GetFullPath($_.command[0]) } } |
	Where-Object { $_.StartsWith($BuildDirectoryPrefix, $PathComparison) -and (Test-Path -PathType Leaf $_) } |
	Sort-Object -Unique)

if (!$Objects) {
	throw 'No test executables were found in the build directory.'
}

$ObjectArguments = @($Objects[0]) + @($Objects | Select-Object -Skip 1 | ForEach-Object { "-object=$_" })

$SourceDirectory = (Get-Location).Path

# The file names in the coverage mapping may use either path separator on Windows:
$BuildDirectoryRegex = ($BuildDirectory -split '[/\\]' | ForEach-Object { [regex]::Escape($_) }) -join '[/\\]'

llvm-cov show `
	-format=html `
	-output-dir $OutputPath `
	-instr-profile $ProfileData `
	-ignore-filename-regex "^$BuildDirectoryRegex[/\\]" `
	@ObjectArguments `
	$SourceDirectory
