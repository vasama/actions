#!/usr/bin/false

if (!$IsWindows) {
	throw 'Visual C is only available on Windows.'
}

function Find-VcVarsDirectory() {
	$VsPath = 'C:/Program Files/Microsoft Visual Studio'
	$VsEditionList = @('Enterprise', 'Professional', 'Community')

	$VsVersions = Get-ChildItem -Path $VsPath -Directory
		| ForEach-Object { $_.Name }
		| Where-Object { $_ -match '20[0-9][0-9]' }
		| Sort-Object -Descending

	foreach ($VsVersion in $VsVersions) {
		$VsVersionPath = "$VsPath/$VsVersion"

		$VsEditions = Get-ChildItem -Path $VsVersionPath -Directory
			| ForEach-Object { [PSCustomObject]@{ Entry=$_; Index=$VsEditionList.IndexOf($_.Name) }}
			| Where-Object { $_['Sort'] -ne -1 }
			| Sort-Object -Property Index
			| ForEach-Object { $_.Entry.Name }

		foreach ($VsEdition in $VsEditions) {
			$VsEditionPath = "$VsVersionPath/$VsEdition"
			$VsVcBuildPath = "$VsEditionPath/VC/Auxiliary/Build"

			if (Test-Path "$VsVcBuildPath/vcvarsall.bat") {
				return $VsVcBuildPath
			}
		}
	}

	throw 'Visual Studio vcvarsall.bat not found.'
}

Push-Location (Find-VcVarsDirectory)
& "$PSScriptRoot/Utilities/Invoke-NativeCommand.ps1" `
	cmd /c 'vcvarsall.bat x64 > nul & set' | ForEach-Object {
		if ($_ -match '^(.+?)=(.*)$') {
			Set-Item -Force -Path "ENV:$($Matches[1])" -Value $Matches[2]
		}
	}
Pop-Location
