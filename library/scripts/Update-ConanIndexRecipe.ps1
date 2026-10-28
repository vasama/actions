#!/usr/bin/pwsh

param(
	[string]$PackageName,
	[string]$PackageVersion,

	# Required by the update-recipe step:
	[string]$ArchiveUrl=$null,
	[string]$ArchiveHash=$null,

	[string]$Step=$null
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$ConanfileVersion = 'v1'
$RecipeDir = "./recipes/$PackageName/$ConanfileVersion"
$RecipeConfig = "./recipes/$PackageName/config.yml"

if (!$Step -or $Step -eq 'update-recipe') {
	if (!$ArchiveUrl -or !$ArchiveHash) {
		throw 'ArchiveUrl and ArchiveHash are required by the update-recipe step.'
	}

	$Conanfile = "$RecipeDir/conanfile.py"
	$Conandata = "$RecipeDir/conandata.yml"

	if (Test-Path -PathType Leaf $Conanfile) {
		$Header = Get-Content -Path $Conanfile -TotalCount 1
		if (!($Header -match "^# VSM-CONANFILE-$ConanfileVersion`$")) {
			throw 'The incompatible existing recipe may not be overwritten.'
		}
	}

	Write-Output "Archive URL: $ArchiveUrl"

	$TemporaryDir = [System.IO.Path]::GetTempPath()
	$TemporaryDir = "$TemporaryDir/$((New-Guid).ToString("N"))"
	New-Item -Path $TemporaryDir -ItemType Directory | Out-Null

	try
	{
		$ArchiveFile = "$TemporaryDir/archive.tar.gz"
		$SourceDir = "$TemporaryDir/source"

		# Download and verify the package archive:
		Invoke-WebRequest $ArchiveUrl -OutFile $ArchiveFile | Out-Null

		$SourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArchiveFile).Hash.ToLowerInvariant()
		if ($SourceHash -ne $ArchiveHash.ToLowerInvariant()) {
			throw "Archive SHA256 mismatch: expected $ArchiveHash, got $SourceHash"
		}

		# Expand the package archive:
		New-Item -Path $SourceDir -ItemType Directory | Out-Null
		tar -xzf $ArchiveFile -C $SourceDir

		# Create the recipe directory:
		New-Item -Path $RecipeDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

		# Update recipe conandata.yml:
		python "$PSScriptRoot/Python/Conan/update_conandata.py" `
			--source $SourceDir `
			--name $PackageName `
			--version $PackageVersion `
			--src-url $ArchiveUrl `
			--src-hash $SourceHash `
			$Conandata

		# Update recipe config.yml, required by the local recipes index:
		python "$PSScriptRoot/Python/Conan/update_recipe_config.py" `
			--version $PackageVersion `
			--folder $ConanfileVersion `
			$RecipeConfig

		# Copy the latest conanfile.py to the recipe directory:
		Copy-Item -Path "$PSScriptRoot/../conan-index/conanfile_$ConanfileVersion.py" -Destination $Conanfile
	}
	finally
	{
		Remove-Item -Path $TemporaryDir -Recurse -Force
	}
}

if (!$Step -or $Step -eq 'create-package') {
	conan create --version $PackageVersion --build missing $RecipeDir
}

if (!$Step -or $Step -eq 'create-commit') {
	git add $RecipeDir $RecipeConfig
	git commit `
		--message "Add $PackageName/$PackageVersion" `
		--message "This commit was created by an automated process."
}

if (!$Step -or $Step -eq 'push-changes') {
	git push
}
