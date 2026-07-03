#!/usr/bin/false

if (!$IsWindows) {
	throw 'Visual C is only available on Windows.'
}

. "$PSScriptRoot/Invoke-NativeCommand.ps1"

function Find-VisualStudio() {
	$VsWhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
	$VsWhere = "$(Invoke-NativeCommand $VsWhere -latest -format json)"
	$VsWhere = ConvertFrom-Json $VsWhere
	return $VsWhere[0].installationPath
}

function Set-VcVars($VsPath) {
	$VcVarsPath = "$VsPath/VC/Auxiliary/Build/vcvarsall.bat"
	$VcVarsPath = Resolve-Path -ErrorAction Stop $VcVarsPath

	Invoke-NativeCommand `
		cmd /c "`"$VcVarsPath`" x64 > nul & set" | ForEach-Object {
			if ($_ -match '^(.+?)=(.*)$') {
				Set-Item -Force -Path "ENV:$($Matches[1])" -Value $Matches[2]
			}
		}
}

if ($MyInvocation.InvocationName -ne '.') {
	Set-VcVars (Find-VisualStudio)
}
