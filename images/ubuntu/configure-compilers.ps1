#!/usr/bin/pwsh

param(
	[Parameter(Mandatory=$true)]
	[string]$GCC,

	[Parameter(Mandatory=$true)]
	[string]$LLVM
)

New-Item -ItemType 'SymbolicLink' -Path '/usr/bin/clang-format' -Value "/usr/bin/clang-format-$LLVM"
New-Item -ItemType 'SymbolicLink' -Path '/usr/bin/clang-tidy'   -Value "/usr/bin/clang-tidy-$LLVM"
