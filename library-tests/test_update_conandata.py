import copy

import pytest
import yaml

from conftest import write_package_info
from update_conandata import get_ver_data, make_package_conandata, merge_ver_data, read_package_json, split_path


REQ_A = { "reference": "a/1.0" }
REQ_B = { "reference": "b/1.0" }
REQ_C = { "reference": "c/1.0", "arguments": { "test": True } }


@pytest.mark.parametrize("path, parts", [
	("a", ["a"]),
	("a/b/c", ["a", "b", "c"]),
	("/a/b", ["/", "a", "b"]),
	("a/b/", ["a", "b"]),
	("a//b", ["a", "b"]),
	("", []),
])
def test_split_path(path, parts):
	assert split_path(path) == parts


def test_read_package_json_merges_from_repository_root(tmp_path):
	write_package_info(tmp_path, { "license": "MIT", "description": "root" })
	write_package_info(tmp_path / "a" / "b", { "description": "b" })

	assert read_package_json(str(tmp_path), "a/b") == { "license": "MIT", "description": "b" }

def test_read_package_json_concatenates_lists(tmp_path):
	write_package_info(tmp_path, { "requirements": [1] })
	write_package_info(tmp_path / "a", { "requirements": [2] })
	write_package_info(tmp_path / "a" / "b", { "requirements": [3] })

	assert read_package_json(str(tmp_path), "a/b")["requirements"] == [1, 2, 3]

def test_read_package_json_missing_raises(tmp_path):
	(tmp_path / "a").mkdir()

	with pytest.raises(RuntimeError, match="package_info.json not found"):
		read_package_json(str(tmp_path), "a")


def test_make_package_conandata_maps_attributes():
	package = {
		"license": "MIT",
		"authors": "Someone",
		"website": "https://example.com",
		"description": "desc",
		"package_type": "static-library",
		"inherit": True,
	}

	assert make_package_conandata(package) == {
		"license": "MIT",
		"author": "Someone",
		"homepage": "https://example.com",
		"description": "desc",
		"package_type": "static-library",
	}

def test_make_package_conandata_requirements():
	package = { "requirements": [
		{ "package": "a", "version": "1.0" },
		{ "package": "b", "version": "2.0", "test": True, "visible": False },
	]}

	assert make_package_conandata(package)["requirements"] == [
		{ "reference": "a/1.0" },
		{ "reference": "b/2.0", "arguments": { "test": True, "visible": False } },
	]

def test_make_package_conandata_omits_empty_requirements():
	assert "requirements" not in make_package_conandata({ "requirements": [] })

def test_make_package_conandata_mistyped_requirement_option_raises():
	package = { "requirements": [{ "package": "a", "version": "1.0", "test": "yes" }] }

	with pytest.raises(RuntimeError, match="Mistyped requirement option: test"):
		make_package_conandata(package)


def test_get_ver_data_without_attributes():
	assert get_ver_data({}, "1.0") == {}

def test_get_ver_data_common_only():
	conandata = { "common_attributes": { "license": "MIT" } }

	assert get_ver_data(conandata, "1.0") == { "license": "MIT" }

def test_get_ver_data_version_overrides_common():
	conandata = {
		"common_attributes": { "license": "MIT", "description": "common" },
		"attributes": { "1.0": { "description": "1.0" } },
	}

	assert get_ver_data(conandata, "1.0") == { "license": "MIT", "description": "1.0" }
	assert get_ver_data(conandata, "2.0") == { "license": "MIT", "description": "common" }

def test_get_ver_data_does_not_modify_conandata():
	conandata = {
		"common_attributes": { "license": "MIT" },
		"attributes": { "1.0": { "description": "1.0" } },
	}
	original = copy.deepcopy(conandata)

	get_ver_data(conandata, "1.0")

	assert conandata == original

def test_get_ver_data_combines_requirements():
	conandata = {
		"common_attributes": { "requirements": [REQ_A] },
		"attributes": { "1.0": { "requirements": [REQ_B] } },
	}

	assert get_ver_data(conandata, "1.0") == { "requirements": [REQ_A, REQ_B] }

def test_get_ver_data_mismatched_type_raises():
	conandata = {
		"common_attributes": { "license": "MIT" },
		"attributes": { "1.0": { "license": ["MIT"] } },
	}

	with pytest.raises(RuntimeError, match="Mismatched type for 'license'"):
		get_ver_data(conandata, "1.0")


def test_merge_ver_data_single_version_is_all_common():
	ver_data = { "1.0": { "license": "MIT", "requirements": [REQ_A] } }

	assert merge_ver_data(ver_data) == { "license": "MIT", "requirements": [REQ_A] }
	assert ver_data == {}

def test_merge_ver_data_shared_and_differing_values():
	ver_data = {
		"1.0": { "license": "MIT", "description": "one" },
		"2.0": { "license": "MIT", "description": "two" },
	}

	assert merge_ver_data(ver_data) == { "license": "MIT" }
	assert ver_data == {
		"1.0": { "description": "one" },
		"2.0": { "description": "two" },
	}

def test_merge_ver_data_key_missing_from_some_versions():
	ver_data = {
		"1.0": { "license": "MIT", "homepage": "https://example.com" },
		"2.0": { "license": "MIT" },
	}

	assert merge_ver_data(ver_data) == { "license": "MIT" }
	assert ver_data == { "1.0": { "homepage": "https://example.com" } }

def test_merge_ver_data_common_attributes_are_ordered():
	ver_data = {
		"1.0": { "description": "d", "license": "MIT", "author": "a" },
		"2.0": { "author": "a", "description": "d", "license": "MIT" },
	}

	assert list(merge_ver_data(ver_data).keys()) == ["license", "author", "description"]

def test_merge_ver_data_identical_requirements():
	ver_data = {
		"1.0": { "requirements": [REQ_A, REQ_B] },
		"2.0": { "requirements": [REQ_A, REQ_B] },
	}

	assert merge_ver_data(ver_data) == { "requirements": [REQ_A, REQ_B] }
	assert ver_data == {}

def test_merge_ver_data_partially_shared_requirements():
	ver_data = {
		"1.0": { "requirements": [REQ_A, REQ_B] },
		"2.0": { "requirements": [REQ_A, REQ_C] },
	}

	assert merge_ver_data(ver_data) == { "requirements": [REQ_A] }
	assert ver_data == {
		"1.0": { "requirements": [REQ_B] },
		"2.0": { "requirements": [REQ_C] },
	}

def test_merge_ver_data_shared_requirements_keep_order():
	ver_data = {
		"1.0": { "requirements": [REQ_C, REQ_A, REQ_B] },
		"2.0": { "requirements": [REQ_B, REQ_C, REQ_A] },
	}

	assert merge_ver_data(ver_data) == { "requirements": [REQ_C, REQ_A, REQ_B] }

def test_merge_ver_data_disjoint_requirements():
	ver_data = {
		"1.0": { "requirements": [REQ_A] },
		"2.0": { "requirements": [REQ_B] },
	}

	assert merge_ver_data(ver_data) == {}
	assert ver_data == {
		"1.0": { "requirements": [REQ_A] },
		"2.0": { "requirements": [REQ_B] },
	}

def test_merge_ver_data_mismatched_type_raises():
	ver_data = {
		"1.0": { "license": "MIT" },
		"2.0": { "license": ["MIT"] },
	}

	with pytest.raises(RuntimeError, match="Mismatched type for 'license'"):
		merge_ver_data(ver_data)

@pytest.mark.parametrize("ver_data", [
	{
		"1.0": { "license": "MIT", "description": "one", "requirements": [REQ_A, REQ_B] },
		"2.0": { "license": "MIT", "description": "two", "requirements": [REQ_A, REQ_C] },
		"3.0": { "license": "MIT", "homepage": "https://example.com", "requirements": [REQ_A] },
	},
	{
		"1.0": { "license": "MIT" },
		"2.0": { "license": "Apache-2.0", "requirements": [REQ_B] },
	},
])
def test_merge_ver_data_round_trips_through_get_ver_data(ver_data):
	original = copy.deepcopy(ver_data)

	common_attributes = merge_ver_data(ver_data)
	conandata = { "common_attributes": common_attributes, "attributes": ver_data }

	for version, attributes in original.items():
		assert get_ver_data(conandata, version) == attributes


@pytest.fixture
def package_repository(tmp_path):
	repo = tmp_path / "repo"
	write_package_info(repo, { "license": "MIT" })
	write_package_info(repo / "pkg", { "description": "pkg" })
	return repo

def update_conandata(run_script, repository, conandata_path, version, *args, name="vsm.pkg", check=True):
	return run_script("update_conandata.py",
		"--root", repository,
		"--path", "pkg",
		"--name", name,
		"--version", version,
		"--src-url", f"https://example.com/{version}.tar.gz",
		"--src-hash", f"hash-{version}",
		*args,
		conandata_path,
		check=check)

def load_yaml(path):
	with open(path, "r") as file:
		return yaml.safe_load(file)

def test_cli_creates_conandata(tmp_path, package_repository, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_repository, conandata_path, "1.0")

	assert load_yaml(conandata_path) == {
		"name": "vsm.pkg",
		"path": "pkg",
		"common_attributes": { "license": "MIT", "description": "pkg" },
		"sources": { "1.0": { "url": "https://example.com/1.0.tar.gz", "sha256": "hash-1.0" } },
	}

def test_cli_adds_version_with_differing_attributes(tmp_path, package_repository, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_repository, conandata_path, "1.0")
	write_package_info(package_repository / "pkg", { "description": "pkg v2" })
	update_conandata(run_script, package_repository, conandata_path, "2.0")

	conandata = load_yaml(conandata_path)

	assert conandata["common_attributes"] == { "license": "MIT" }
	assert conandata["attributes"] == {
		"1.0": { "description": "pkg" },
		"2.0": { "description": "pkg v2" },
	}
	assert list(conandata["sources"].keys()) == ["1.0", "2.0"]

def test_cli_replaces_existing_version(tmp_path, package_repository, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_repository, conandata_path, "1.0")
	write_package_info(package_repository / "pkg", { "description": "changed" })
	update_conandata(run_script, package_repository, conandata_path, "1.0")

	conandata = load_yaml(conandata_path)

	assert conandata["common_attributes"] == { "license": "MIT", "description": "changed" }
	assert "attributes" not in conandata
	assert list(conandata["sources"].keys()) == ["1.0"]

def test_cli_mismatched_name_fails(tmp_path, package_repository, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_repository, conandata_path, "1.0")
	result = update_conandata(run_script, package_repository, conandata_path, "2.0", name="other", check=False)

	assert result.returncode != 0
	assert "Mismatched package name" in result.stderr
