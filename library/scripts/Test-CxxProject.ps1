#!/usr/bin/pwsh

param(
	[string]$Tool=$null,
	[string]$Config="Debug",
	[string]$BuildSystem=$null,

	[string]$ConanBuild=$null,
	[string[]]$ConanProfile=@(),
	[string]$Step=$null,

	[switch]$CMakeWarningsAsErrors=$false,

	[switch]$WhatIf=$false
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Compiler = $null
$Analysis = $null

if ($Tool) {
	$ToolComponents = $Tool -split '/',2
	$Compiler = $ToolComponents[0]

	if ($ToolComponents.Count -gt 1) {
		$Analysis = $ToolComponents[1]
	}
}

$DefaultBuildSystem = 'ninja'
if ($IsWindows) {
	$OS = 'windows'

	if (!$Compiler) {
		$Compiler = 'msvc'
	}

	if ($Compiler -in @('msvc', 'clang-cl')) {
		$DefaultBuildSystem = 'visual-studio'
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

if (!$BuildSystem) {
	if ($Analysis) {
		$BuildSystem = 'ninja'
	} else {
		$BuildSystem = $DefaultBuildSystem
	}
}

if ($Compiler -eq 'clang' -and $BuildSystem -eq 'visual-studio') {
	throw 'clang does not support visual-studio, use clang-cl instead'
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

$ConanArguments += @("-pr=vsm-host")
$ConanArguments += @("-pr=vsm-${Compiler}")

$ConanProfileRoot = Resolve-Path -ErrorAction Stop "$PSScriptRoot/../conan"
function Include-ConanProfile($Profile) {
	$ProfilePath = Resolve-Path -ErrorAction SilentlyContinue "$script:ConanProfileRoot/$Profile"
	if ($? -and (Test-Path -PathType Leaf $ProfilePath)) {
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

# The additional profiles may not change the build folder variables.
$ConanArguments += @($ConanProfile | ForEach-Object { "-pr=$_" })

$ConanPreset = "$ConanPreset-$($Config.ToLowerInvariant())"
$CMakePreset = "conan-$ConanPreset"
$BuildDirectory = "./build/$ConanPreset"

if ($Step -eq 'build-directory') {
	Write-Output $BuildDirectory
}

if ($Step -eq 'conan-package-id') {
	$ConanGraphInfo = conan graph info --format json @ConanArguments .
	$ConanGraphInfo = (ConvertFrom-Json -AsHashtable "$ConanGraphInfo")['graph']

	$ConanGraphRoot = $ConanGraphInfo['root']
	if ($ConanGraphRoot.Length -ne 1) {
		throw 'Invalid Conan graph'
	}

	$ConanGraphRoot = $ConanGraphInfo['nodes'][$ConanGraphRoot.Keys[0]]
	if ($ConanGraphRoot.recipe -ne 'Consumer') {
		throw 'Invalid Conan graph'
	}

	Write-Output $ConanGraphRoot['package_id']
}

if (!$Step -or $Step -eq 'conan-install') {
	if ($ConanBuild) {
		$ConanArguments += @("-b=$ConanBuild")
	}

	if ($WhatIf) {
		Write-Output "conan install $($ConanArguments | ForEach-Object { "'$_'" } | Join-String -Separator ' ') ."
	} else {
		conan install @ConanArguments .
	}
}

if (!$Step -or $Step -eq 'cmake-configure') {
	$CMakeArguments = @("--preset", $CMakePreset)
	if ($CMakeWarningsAsErrors) {
		$CMakeArguments += @("-Werror=dev")
	}

	if ($WhatIf) {
		Write-Output "cmake $($CMakeArguments -join ' ')"
	} else {
		cmake @CMakeArguments
	}
}

if ((!$Step -and !$Analysis) -or $Step -eq 'cmake-build') {
	if ($WhatIf) {
		Write-Output "cmake --build --preset $CMakePreset"
	} else {
		cmake --build --preset $CMakePreset
	}
}

if ((!$Step -and !$Analysis) -or $Step -eq 'ctest') {
	if ($WhatIf) {
		Write-Output "ctest --preset $CMakePreset --output-on-failure"
	} else {
		ctest --preset $CMakePreset --output-on-failure
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
