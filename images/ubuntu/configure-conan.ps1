#!/usr/bin/pwsh

param(
	[Parameter(Mandatory=$true)]
	[string]$Architecture,

	[Parameter(Mandatory=$true)]
	[string]$GCC,

	[Parameter(Mandatory=$true)]
	[string]$LLVM
)

$PSNativeCommandUseErrorActionPreference = $true

function Generate-HostProfile() {
	Write-Output '[platform_tool_requires]'

	if (!("$(cmake --version)" -match 'cmake version (\d+\.\d+\.\d+)\b')) {
		throw 'Unable to detect CMake version'
	}

	Write-Output "cmake/$($Matches[1])"
}

function Generate-CompilerProfile($Compiler, $CXXCompiler, $Version) {
	Write-Output "include(vsm-host)"

	Write-Output '[settings]'
	Write-Output "arch=$Architecture"
	Write-Output "compiler=$Compiler"
	Write-Output "compiler.cppstd=23"
	Write-Output "compiler.libcxx=libstdc++11"
	Write-Output "compiler.version=$Version"
	Write-Output 'os=Linux'

	Write-Output '[conf]'
	Write-Output "tools.build:compiler_executables={`"c`": `"$Compiler-$Version`", `"cpp`": `"$CXXCompiler-$Version`"}"
}

function Generate-DefaultProfile($Compiler, $Config) {
	Write-Output "include(vsm-host)"
	Write-Output "include(vsm-$Compiler)"

	Write-Output '[settings]'
	Write-Output "build_type=$Config"
}

# Run Conan for the first time to create configuration directory.
conan | Out-Null

if (!(Test-Path -PathType Container $ENV:CONAN_HOME)) {
	throw 'Conan configuration directory was not created as expected.'
}

$ProfilesDirectory = "$ENV:CONAN_HOME/profiles"
if (!(Test-Path -PathType Container $ProfilesDirectory)) {
	New-Item -ItemType Directory $ProfilesDirectory
}

Generate-HostProfile                             | Out-File "$ProfilesDirectory/vsm-host"
Generate-CompilerProfile 'gcc'   'g++'     $GCC  | Out-File "$ProfilesDirectory/vsm-gcc"
Generate-CompilerProfile 'clang' 'clang++' $LLVM | Out-File "$ProfilesDirectory/vsm-clang"
Generate-DefaultProfile  'gcc'   'Debug'         | Out-File "$ProfilesDirectory/default"
