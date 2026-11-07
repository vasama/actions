#!/usr/bin/pwsh

param(
	[string]$OutputPath='./coverage'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$TestScript = Resolve-Path -ErrorAction Stop "$PSScriptRoot/Test-CxxProject.ps1"
$CoverageProfile = Resolve-Path -ErrorAction Stop "$PSScriptRoot/../conan/coverage"

$TestArguments = @{
	Tool = 'clang'
	Config = 'Debug'
	ConanProfile = @($CoverageProfile.Path)
}

# The build directory may not exist yet:
$BuildDirectory = & $TestScript @TestArguments -Step build-directory
$BuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory, (Get-Location).Path)

$ProfileDirectory = "$BuildDirectory/vsm-coverage"
$ProfileData = "$ProfileDirectory/coverage.profdata"

# The instrumented binaries are found using the CMake file API:
$FileApiDirectory = "$BuildDirectory/.cmake/api/v1"
$FileApiQuery = "$FileApiDirectory/query/codemodel-v2"

# Profiles from previous runs would distort the results:
if (Test-Path $ProfileDirectory) {
	Remove-Item -Recurse -Force $ProfileDirectory
}

New-Item -ItemType File -Force -Path $FileApiQuery | Out-Null

$ENV:LLVM_PROFILE_FILE = "$ProfileDirectory/%p-%m.profraw"
try {
	& $TestScript @TestArguments -ConanBuild missing
} finally {
	$ENV:LLVM_PROFILE_FILE = $null
}

$RawProfiles = @(Get-ChildItem -Path $ProfileDirectory -Filter '*.profraw' | ForEach-Object FullName)
if (!$RawProfiles) {
	throw 'No coverage profiles were produced by the tests.'
}

llvm-profdata merge -sparse -o $ProfileData @RawProfiles

function Read-FileApiReply($File) {
	return Get-Content -Raw "$FileApiDirectory/reply/$File" | ConvertFrom-Json
}

# The newest index file describes the latest configuration:
$FileApiIndex = Get-ChildItem -Path "$FileApiDirectory/reply" -Filter 'index-*.json' | Sort-Object Name | Select-Object -Last 1
$Codemodel = Read-FileApiReply (Read-FileApiReply $FileApiIndex.Name).reply.'codemodel-v2'.jsonFile

$CodemodelConfig = $Codemodel.configurations | Where-Object name -eq 'Debug'
if (!$CodemodelConfig) {
	throw 'The CMake code model does not contain the Debug configuration.'
}

$Objects = @()
foreach ($TargetReference in $CodemodelConfig.targets) {
	$Target = Read-FileApiReply $TargetReference.jsonFile

	if ($Target.type -notin @('EXECUTABLE', 'SHARED_LIBRARY', 'MODULE_LIBRARY')) {
		continue
	}

	foreach ($Artifact in $Target.artifacts) {
		$Path = [System.IO.Path]::GetFullPath($Artifact.path, $Codemodel.paths.build)

		# Import libraries and debug information files are also listed as artifacts on Windows:
		$IsBinary = !$IsWindows -or [System.IO.Path]::GetExtension($Path) -in @('.exe', '.dll')

		if ($IsBinary -and (Test-Path -PathType Leaf $Path)) {
			$Objects += $Path
		}
	}
}

if (!$Objects) {
	throw 'No binaries were found in the CMake code model.'
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
