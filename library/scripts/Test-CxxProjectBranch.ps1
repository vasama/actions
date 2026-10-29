#!/usr/bin/pwsh

[CmdletBinding(PositionalBinding=$false)]
param(
	[string]$BaseRef=$null,
	[switch]$WhatIf=$false,

	[Parameter(ValueFromRemainingArguments)]
	[string[]]$ScriptArguments=@()
)

& "$PSScriptRoot/Test-GitBranch.ps1" `
	-BaseRef $BaseRef `
	-Script "$PSScriptRoot/Test-CxxProjectCommit.ps1" `
	-WhatIf:$WhatIf `
	@ScriptArguments
