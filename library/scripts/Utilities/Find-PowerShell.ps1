#!/usr/bin/false

function Find-PowerShell {
	$Version = $PSVersionTable.PSVersion
	if ($Version.Major -gt 7 -or ($Version.Major -eq 7 -and $Version.Minor -ge 2)) {
		return [Environment]::ProcessPath
	}
	return (Get-Process -Id $PID).Path
}

if ($MyInvocation.InvocationName -ne '.') {
	return Find-PowerShell
}
