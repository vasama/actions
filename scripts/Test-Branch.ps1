param(
	[Parameter(Position=0, Mandatory=$true)]
	[string]$Script,

	[string]$BaseRef=$null,
)

. "$PSScriptRoot/Utilities/Invoke-NativeCommand.ps1"

function Test-GitBranch($BranchName) {
	git show-ref --verify --quiet "refs/heads/$BranchName"
	return $LastExitCode -eq 0
}

function Select-BaseRef {
	for ($Candidate in @('develop', 'main', 'master')) {
		if (Test-GitBranch $Candidate) {
			return $Candidate
		}
	}

	throw 'unable to deduce base ref'
}

if (!$BaseRef) {
	$BaseRef = Select-BaseRef
}

Invoke-NativeCommand git rebase --exec $Script
