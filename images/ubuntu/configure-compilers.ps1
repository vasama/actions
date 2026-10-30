#!/usr/bin/pwsh

param(
	[Parameter(Mandatory=$true)]
	[string]$GCC,

	[Parameter(Mandatory=$true)]
	[string]$LLVM
)

$PSNativeCommandUseErrorActionPreference = $true

New-Item -ItemType 'SymbolicLink' -Path '/usr/bin/clang-format'  -Value "/usr/bin/clang-format-$LLVM"
New-Item -ItemType 'SymbolicLink' -Path '/usr/bin/clang-tidy'    -Value "/usr/bin/clang-tidy-$LLVM"
New-Item -ItemType 'SymbolicLink' -Path '/usr/bin/llvm-cov'      -Value "/usr/bin/llvm-cov-$LLVM"
New-Item -ItemType 'SymbolicLink' -Path '/usr/bin/llvm-profdata' -Value "/usr/bin/llvm-profdata-$LLVM"
