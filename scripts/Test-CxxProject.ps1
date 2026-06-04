#!/usr/bin/pwsh

param(
	[string]$Tool=$null,
	[string]$Config="Debug",
	[string]$BuildSystem=$null,

	[string]$ConanBuild=$null,
	[string]$Step=$null,

	[switch]$WhatIf=$false
)

. "$PSScriptRoot/Utilities/Invoke-NativeCommand.ps1"

$Compiler = $null
$Analysis = $null

if ($Tool) {
	$ToolComponents = $Tool -split '-',2
	$Compiler = $ToolComponents[0]

	if ($ToolComponents.Count -gt 1) {
		$Analysis = $ToolComponents[1]
	}
}

if ($IsWindows) {
	$OS = 'windows'
	if (!$Compiler) {
		$Compiler = 'msvc'
	}
} elseif ($IsLinux) {
	$OS = 'linux'
	if (!$Compiler) {
		$Compiler = 'gcc'
	}
} else {
	throw 'unsupported platform'
}

$Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
$Architecture = switch ($Architecture) {
	'X86' { 'x86' }
	'X64' { 'x86_64' }
	default { throw 'unsupported architecture' }
}

$DefaultBuildSystem = 'ninja'
if ($Compiler -eq 'msvc') {
	$DefaultBuildSystem = 'visual-studio'
}

if (!$BuildSystem) {
	if ($Analysis) {
		$BuildSystem = 'ninja'
	} else {
		$BuildSystem = $DefaultBuildSystem
	}
}

if ($Analysis) {
	if ($BuildSystem -ne 'ninja') {
		throw "tool $Tool requires the use of ninja"
	}

	$AnalysisModule = "$PSScriptRoot/CxxAnalysisModules/$Compiler-$Analysis.ps1"
	if (!(Test-Path -PathType Leaf $AnalysisModule)) {
		throw "no such analysis: $Analysis"
	}
	. $AnalysisModule
}

$ConanSettings = @("build_type=$Config")
if ($IsWindows) {
	$ConanSettings += @("compiler.runtime_type=$Config")
}

$ConanArguments = @($ConanSettings | ForEach-Object { "-s=$_" })
$ConanArguments += @("-pr=vsm-${Compiler}")

$ConanProfileRoot = Resolve-Path "$PSScriptRoot/../conan/profiles"
function Include-ConanProfile($Profile) {
	$ProfilePath = "$script:ConanProfileRoot/$Profile"
	if (Test-Path -PathType Leaf $ProfilePath) {
		$script:ConanArguments += @("-pr=$ProfilePath")
	}
}

Include-ConanProfile 'tags-prologue'
Include-ConanProfile "$BuildSystem"
Include-ConanProfile "$BuildSystem-$Compiler"

Include-ConanProfile 'tags-compiler'
Include-ConanProfile "$Compiler"
Include-ConanProfile "$Compiler-$Architecture"

$ConanPreset = 'vsm'
if ($BuildSystem -ne $DefaultBuildSystem) {
	$ConanPreset = "$ConanPreset-$BuildSystem"
}

$ConanPreset = "$ConanPreset-$Compiler"
if ($Analysis) {
	$ConanPreset = "$ConanPreset-$Analysis"
	Include-ConanProfile "$Compiler-$Analysis"
}

Include-ConanProfile 'tags-epilogue'

$ConanPreset = "$ConanPreset-$($Config.ToLowerInvariant())"
$CMakePreset = "conan-$ConanPreset"
$BuildDirectory = "./build/$ConanPreset"

if (!$Step -or $Step -eq 'conan-install') {
	if ($ConanBuild) {
		$ConanArguments += @("-b=$ConanBuild")
	}

	if ($WhatIf) {
		Write-Output "conan install $ConanArguments ."
	} else {
		Invoke-NativeCommand conan install @ConanArguments .
	}
}

if (!$Step -or $Step -eq 'cmake-configure') {
	if ($WhatIf) {
		Write-Output "cmake --preset $CMakePreset"
	} else {
		Invoke-NativeCommand cmake --preset $CMakePreset
	}
}

if ((!$Step -and !$Analysis) -or $Step -eq 'cmake-build') {
	if ($WhatIf) {
		Write-Output "cmake --build --preset $CMakePreset"
	} else {
		Invoke-NativeCommand cmake --build --preset $CMakePreset
	}
}

if ((!$Step -and !$Analysis) -or $Step -eq 'ctest') {
	if ($WhatIf) {
		Write-Output "ctest --preset $CMakePreset --output-on-failure"
	} else {
		Invoke-NativeCommand ctest --preset $CMakePreset --output-on-failure
	}
}

if ((!$Step -and $Analysis) -or $Step -eq 'analyze') {
	$CompileCommands = "$BuildDirectory/compile_commands.json"
	$CompileCommands = ConvertFrom-Json (Get-Content -Raw $CompileCommands)

	$AnalysisExpressions = $CompileCommands | ForEach-Object {
		return Format-AnalysisExpression $BuildDirectory $_
	}

	if ($WhatIf) {
		foreach ($Expression in $AnalysisExpressions) {
			Write-Output $Expression
			Write-Output ''
		}
	} else {
		$Results = $AnalysisExpressions | ForEach-Object -Parallel {
			$Output = Invoke-Expression $_

			return @{
				Expression = $_;
				ExitCode = $LastExitCode;
				Output = $Output;
			}
		}

		$Status = $True
		foreach ($Result in $Results) {
			if ($Result.ExitCode -ne 0) {
				Write-Output $Result.Expression
				Write-Output $Result.Output
				Write-Output ''

				$Status = $False
			}
		}

		if (!$Status) {
			exit 1
		}
	}
}
