import io
import json
import os
import stat
import subprocess
import tarfile

import pytest

from conftest import write_package_info
from make_package_archive import add_file_from_string, get_file_size, get_tracked_files


def git(path, *args):
	subprocess.run(
		["git", "-C", str(path),
			"-c", "user.name=test",
			"-c", "user.email=test@example.com",
			*args],
		check=True,
		capture_output=True)

@pytest.fixture
def repository(tmp_path):
	"""A git repository with a package in the pkg subdirectory."""

	repo = tmp_path / "repo"
	pkg = repo / "pkg"
	pkg.mkdir(parents=True)

	write_package_info(repo, { "license": "MIT" })
	write_package_info(pkg, { "inherit": True, "description": "pkg" })

	(repo / "README.md").write_text("readme")
	(pkg / "CMakeLists.txt").write_text("cmake")
	(pkg / "run.sh").write_text("#!/bin/sh\n")
	os.chmod(pkg / "run.sh", 0o755)

	git(repo, "init", "-q")
	git(repo, "add", ".")
	git(repo, "commit", "-q", "-m", "init")

	# Untracked files are not part of the package:
	(pkg / "untracked.txt").write_text("untracked")

	return repo


def test_get_file_size_preserves_position():
	file = io.BytesIO(b"0123456789")
	file.seek(3)

	assert get_file_size(file) == 10
	assert file.tell() == 3


def test_get_tracked_files_lists_package_files(repository):
	files = dict(get_tracked_files(str(repository / "pkg"), "HEAD"))

	assert files == {
		"CMakeLists.txt": "100644",
		"package_info.json": "100644",
		"run.sh": "100755",
	}


def test_add_file_from_string(tmp_path):
	archive_path = tmp_path / "archive.tar"

	with tarfile.open(archive_path, "w") as tar:
		add_file_from_string(tar, "a.txt", "hello")

	with tarfile.open(archive_path, "r") as tar:
		info = tar.getmember("a.txt")
		assert info.mode == 0o644
		assert tar.extractfile(info).read() == b"hello"


def make_archive(run_script, repository, archive_path, *args, check=True):
	return run_script("make_package_archive.py",
		"--package-path", repository / "pkg",
		"--archive-path", archive_path,
		*args,
		check=check)

def test_cli_archives_tracked_files(tmp_path, repository, run_script):
	archive_path = tmp_path / "archive.tar.gz"
	make_archive(run_script, repository, archive_path, "--overwrite")

	with tarfile.open(archive_path, "r:gz") as tar:
		assert sorted(tar.getnames()) == ["CMakeLists.txt", "package_info.json", "run.sh"]
		assert tar.extractfile("CMakeLists.txt").read() == b"cmake"

def test_cli_writes_merged_package_info(tmp_path, repository, run_script):
	archive_path = tmp_path / "archive.tar.gz"
	make_archive(run_script, repository, archive_path, "--overwrite")

	with tarfile.open(archive_path, "r:gz") as tar:
		package_info = json.load(tar.extractfile("package_info.json"))

	assert package_info == { "license": "MIT", "description": "pkg" }

def test_cli_package_info_without_inherit_stands_alone(tmp_path, repository, run_script):
	write_package_info(repository / "pkg", { "description": "pkg" })
	git(repository, "commit", "-q", "-am", "standalone")

	archive_path = tmp_path / "archive.tar.gz"
	make_archive(run_script, repository, archive_path)

	with tarfile.open(archive_path, "r:gz") as tar:
		package_info = json.load(tar.extractfile("package_info.json"))

	assert package_info == { "description": "pkg" }

def test_cli_preserves_file_modes(tmp_path, repository, run_script):
	archive_path = tmp_path / "archive.tar.gz"
	make_archive(run_script, repository, archive_path, "--overwrite")

	with tarfile.open(archive_path, "r:gz") as tar:
		assert stat.S_IMODE(tar.getmember("CMakeLists.txt").mode) == 0o644
		assert stat.S_IMODE(tar.getmember("run.sh").mode) == 0o755

def test_cli_creates_archive_without_overwrite(tmp_path, repository, run_script):
	archive_path = tmp_path / "archive.tar.gz"
	result = make_archive(run_script, repository, archive_path, check=False)

	assert result.returncode == 0, result.stderr
	assert tarfile.is_tarfile(archive_path)

def test_cli_refuses_existing_archive_without_overwrite(tmp_path, repository, run_script):
	archive_path = tmp_path / "archive.tar.gz"
	archive_path.write_bytes(b"existing")

	result = make_archive(run_script, repository, archive_path, check=False)

	assert result.returncode != 0
	assert archive_path.read_bytes() == b"existing"

def test_cli_overwrites_existing_archive(tmp_path, repository, run_script):
	archive_path = tmp_path / "archive.tar.gz"
	archive_path.write_bytes(b"existing")

	make_archive(run_script, repository, archive_path, "--overwrite")

	assert tarfile.is_tarfile(archive_path)
