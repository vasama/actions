#!/usr/bin/false

function Format-AnalysisExpression($BuildDirectory, $CompileCommand) {
	$ConfigPath = Resolve-Path "$PSScriptRoot/../../../.clang-tidy"
	return "clang-tidy --config-file $ConfigPath -p '$BuildDirectory' '$($CompileCommand.file)' 2>&1"
}
