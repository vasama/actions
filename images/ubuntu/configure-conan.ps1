#!/usr/bin/pwsh

param(
	[Parameter(Mandatory=$true)]
	[string]$Architecture,

	[Parameter(Mandatory=$true)]
	[string]$GCC,

	[Parameter(Mandatory=$true)]
	[string]$LLVM
)

function Generate-HostProfile() {
	Write-Output '[platform_tool_requires]'

	"$(cmake --version)" -match 'cmake version (\d\.\d\.\d)'
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
	Write-Output "include(vsm-$Compiler)"

	Write-Output '[settings]'
	Write-Output "build_type=$Config"
}

# Run Conan for the first time to create configuration directory.
conan | Out-Null

if ($LastExitCode -ne 0) {
	exit $LastExitCode
}

if (!(Test-Path -PathType Container $CONAN_HOME)) {
	throw "Conan configuration directory was not created as expected."
}

$ProfilesDirectory = "$CONAN_HOME/profiles"
if (!(Test-Path -PathType Container $ProfilesDirectory)) {
	New-Item -ItemType Directory $ProfilesDirectory
}

Generate-HostProfile                             | Out-File "$ProfilesDirectory/vsm-host"
Generate-CompilerProfile 'gcc'   'g++'     $GCC  | Out-File "$ProfilesDirectory/vsm-gcc"
Generate-CompilerProfile 'clang' 'clang++' $LLVM | Out-File "$ProfilesDirectory/vsm-clang"
Generate-DefaultProfile  'gcc'   'Debug'         | Out-File "$ProfilesDirectory/default"
