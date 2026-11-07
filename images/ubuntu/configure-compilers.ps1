#!/usr/bin/pwsh

param(
	[Parameter(Mandatory=$true)]
	[string]$GCC,

	[Parameter(Mandatory=$true)]
	[string]$LLVM
)

$ErrorActionPreference = 'Stop'

function Add-LlvmToolLink($Tool) {
	$Unversioned = "/usr/bin/$Tool"
	$Versioned = "$Unversioned-$LLVM"

	if (!(Test-Path -PathType Leaf $Versioned)) {
		throw "LLVM tool '$Versioned' does not exist."
	}

	New-Item -ItemType 'SymbolicLink' -Path $Unversioned -Value $Versioned
}

Add-LlvmToolLink 'clang-format'
Add-LlvmToolLink 'clang-tidy'
Add-LlvmToolLink 'llvm-cov'
Add-LlvmToolLink 'llvm-profdata'
Add-LlvmToolLink 'llvm-symbolizer'
