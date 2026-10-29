#!/usr/bin/pwsh

param(
	[string]$BaseRef=$null,
	[switch]$WhatIf=$false
)

& "$PSScriptRoot/Test-GitBranch.ps1" `
	-BaseRef $BaseRef `
	-Script "$PSScriptRoot/Test-CxxProjectCommit.ps1" `
	-WhatIf:$WhatIf
