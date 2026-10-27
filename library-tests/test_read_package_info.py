import json
import os

import pytest

from conftest import write_package_info
from read_package_info import read_package_info


def test_reads_single_file(tmp_path):
	write_package_info(tmp_path, { "license": "MIT" })

	assert read_package_info(str(tmp_path)) == { "license": "MIT" }

def test_missing_file_raises(tmp_path):
	with pytest.raises(Exception, match="package_info.json not found"):
		read_package_info(str(tmp_path / "a" / "b"))

def test_does_not_search_parents_without_inherit(tmp_path):
	write_package_info(tmp_path, { "license": "MIT" })
	package_dir = tmp_path / "a" / "b"
	package_dir.mkdir(parents=True)

	with pytest.raises(Exception, match="package_info.json not found"):
		read_package_info(str(package_dir))

def test_without_inherit_stops_at_first_file(tmp_path):
	write_package_info(tmp_path, { "license": "MIT", "description": "root" })
	write_package_info(tmp_path / "pkg", { "description": "pkg" })

	assert read_package_info(str(tmp_path / "pkg")) == { "description": "pkg" }

def test_inherit_merges_parent(tmp_path):
	write_package_info(tmp_path, { "license": "MIT", "description": "root" })
	write_package_info(tmp_path / "pkg", { "inherit": True, "description": "pkg" })

	assert read_package_info(str(tmp_path / "pkg")) == {
		"license": "MIT",
		"description": "pkg",
		"inherit": True,
	}

def test_inherit_skips_directories_without_package_info(tmp_path):
	write_package_info(tmp_path, { "license": "MIT" })
	write_package_info(tmp_path / "a" / "b", { "inherit": True, "description": "b" })

	assert read_package_info(str(tmp_path / "a" / "b")) == {
		"license": "MIT",
		"description": "b",
		"inherit": True,
	}

def test_inherit_without_parent_raises(tmp_path):
	write_package_info(tmp_path, { "inherit": True })

	with pytest.raises(Exception, match="Inherited package_info.json not found"):
		read_package_info(str(tmp_path))

def test_inherit_chain_stops_at_non_inheriting_file(tmp_path):
	write_package_info(tmp_path, { "license": "Apache-2.0" })
	write_package_info(tmp_path / "a", { "license": "MIT" })
	write_package_info(tmp_path / "a" / "b", { "inherit": True, "description": "b" })

	result = read_package_info(str(tmp_path / "a" / "b"))

	assert result["license"] == "MIT"
	assert result["description"] == "b"

def test_inherit_concatenates_lists_parent_first(tmp_path):
	write_package_info(tmp_path, { "requirements": [{ "package": "a", "version": "1" }] })
	write_package_info(tmp_path / "pkg", {
		"inherit": True,
		"requirements": [{ "package": "b", "version": "2" }],
	})

	result = read_package_info(str(tmp_path / "pkg"))

	assert result["requirements"] == [
		{ "package": "a", "version": "1" },
		{ "package": "b", "version": "2" },
	]

def test_non_bool_inherit_raises(tmp_path):
	write_package_info(tmp_path, { "inherit": "yes" })

	with pytest.raises(Exception, match="Invalid inherit field"):
		read_package_info(str(tmp_path))


def test_cli_prints_combined_json_without_inherit(tmp_path, run_script):
	write_package_info(tmp_path, { "license": "MIT" })
	write_package_info(tmp_path / "pkg", { "inherit": True, "description": "pkg" })

	result = run_script("read_package_info.py", tmp_path / "pkg")

	assert json.loads(result.stdout) == { "license": "MIT", "description": "pkg" }

def test_cli_accepts_file_without_inherit_field(tmp_path, run_script):
	write_package_info(tmp_path, { "license": "MIT" })

	result = run_script("read_package_info.py", tmp_path, check=False)

	assert result.returncode == 0, result.stderr
	assert json.loads(result.stdout) == { "license": "MIT" }
