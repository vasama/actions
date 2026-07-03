#!/usr/bin/false

function Format-AnalysisExpression($BuildDirectory, $CompileCommand) {
	return "$($CompileCommand.command) /BE /D__INTELLISENSE__=1"
}
