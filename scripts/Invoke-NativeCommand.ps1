#!/usr/bin/false

function Invoke-NativeCommand($Command) {
	& $Command $Args
	if (!$?) { exit 1 }
}

if ($MyInvocation.InvocationName -ne '.') {
	Invoke-NativeCommand $Args
}
