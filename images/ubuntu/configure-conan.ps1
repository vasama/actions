#!/usr/bin/pwsh

param(
	[Parameter(Mandatory=$true)]
	[string]$ConanDirectory,

	[Parameter(Mandatory=$true)]
	[string]$Architecture,

	[Parameter(Mandatory=$true)]
	[string]$GCC,

	[Parameter(Mandatory=$true)]
	[string]$LLVM
)

function Generate-CompilerProfile($Compiler, $CXXCompiler, $Version) {
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

$ConfigurationDirectory = "$ENV:HOME/.conan2"
if (!(Test-Path -PathType Container $ConfigurationDirectory)) {
	throw "Conan configuration directory was not created as expected."
}

$ProfilesDirectory = "$ConfigurationDirectory/profiles"
New-Item -ItemType Directory $ProfilesDirectory -ErrorAction SilentlyContinue

Generate-CompilerProfile 'gcc'   'g++'     $GCC  | Out-File "$ProfilesDirectory/vsm-gcc"
Generate-CompilerProfile 'clang' 'clang++' $LLVM | Out-File "$ProfilesDirectory/vsm-clang"
Generate-DefaultProfile  'gcc'   'Debug'         | Out-File "$ProfilesDirectory/default"
