import copy

import pytest
import yaml

from conftest import write_package_info
from update_conandata import get_ver_data, make_package_conandata, merge_ver_data, read_package_json


REQ_A = { "reference": "a/1.0" }
REQ_B = { "reference": "b/1.0" }
REQ_C = { "reference": "c/1.0", "arguments": { "test": True } }


def test_read_package_json(tmp_path):
	package_info = { "license": "MIT", "requirements": [{ "package": "a", "version": "1.0" }] }
	write_package_info(tmp_path, package_info)

	assert read_package_json(str(tmp_path)) == package_info

@pytest.mark.parametrize("requirement", [{ "package": "a" }, { "version": "1.0" }])
def test_read_package_json_incomplete_requirement_raises(tmp_path, requirement):
	write_package_info(tmp_path, { "requirements": [requirement] })

	with pytest.raises(Exception, match="is a required property"):
		read_package_json(str(tmp_path))

def test_read_package_json_invalid_raises(tmp_path):
	write_package_info(tmp_path, { "license": 1 })

	with pytest.raises(Exception, match="1 is not of type 'string'"):
		read_package_json(str(tmp_path))

def test_read_package_json_missing_raises(tmp_path):
	with pytest.raises(RuntimeError, match="package_info.json not found"):
		read_package_json(str(tmp_path))


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

TOOL_ARGUMENTS = { "build": True, "headers": False, "libs": False, "run": True, "visible": False }

def make_requirements(*configs):
	package = { "requirements": [{ "package": "a", "version": "1.0", "configs": c } for c in configs] }
	return make_package_conandata(package)["requirements"]

def test_make_package_conandata_requirement_defaults_to_header_library():
	package = { "requirements": [{ "package": "a", "version": "1.0" }] }

	assert make_package_conandata(package)["requirements"] == [
		{ "reference": "a/1.0", "arguments": { "transitive_headers": True } },
	]

@pytest.mark.parametrize("config, requirement", [
	("header-library", { "arguments": { "transitive_headers": True } }),
	("source-library", {}),
	("test-library", {
		"arguments": { "headers": True, "libs": True, "test": True, "visible": False },
		"testing": True,
	}),
	("header-application", { "arguments": { **TOOL_ARGUMENTS, "visible": True } }),
	("source-application", { "arguments": TOOL_ARGUMENTS }),
	("test-application", { "arguments": TOOL_ARGUMENTS, "testing": True }),
])
def test_make_package_conandata_requirement_config(config, requirement):
	assert make_requirements(config) == [{ "reference": "a/1.0", **requirement }]

def test_make_package_conandata_requirement_config_list_is_used_two_ways():
	assert make_requirements(["source-library", "test-application"]) == [
		{ "reference": "a/1.0" },
		{ "reference": "a/1.0", "arguments": TOOL_ARGUMENTS, "testing": True },
	]

def test_make_package_conandata_requirements_do_not_share_objects():
	requirements = make_requirements("source-application", "source-application")

	assert requirements[0]["arguments"] is not requirements[1]["arguments"]

def test_make_package_conandata_omits_empty_requirements():
	assert "requirements" not in make_package_conandata({ "requirements": [] })

def test_make_package_conandata_unsupported_config_asserts():
	with pytest.raises(AssertionError):
		make_requirements("unknown")

def test_make_package_conandata_mistyped_configs_asserts():
	with pytest.raises(AssertionError):
		make_requirements(True)

@pytest.mark.parametrize("configs", [
	["header-library", "test-library"],
	["header-application", "source-application"],
])
def test_make_package_conandata_same_context_configs_raise(configs):
	with pytest.raises(RuntimeError, match="Conflicting requirement configs"):
		make_requirements(configs)


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

	assert list(merge_ver_data(ver_data).keys()) == ["author", "description", "license"]

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
def package_directory(tmp_path):
	directory = tmp_path / "package"
	write_package_info(directory, { "license": "MIT", "description": "pkg" })
	return directory

def update_conandata(run_script, directory, conandata_path, version, *args, name="vsm.pkg", check=True):
	return run_script("update_conandata.py",
		"--source", directory,
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

def test_cli_creates_conandata(tmp_path, package_directory, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_directory, conandata_path, "1.0")

	assert load_yaml(conandata_path) == {
		"name": "vsm.pkg",
		"common_attributes": { "license": "MIT", "description": "pkg" },
		"sources": { "1.0": { "url": "https://example.com/1.0.tar.gz", "sha256": "hash-1.0" } },
	}

def test_cli_adds_version_with_differing_attributes(tmp_path, package_directory, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_directory, conandata_path, "1.0")
	write_package_info(package_directory, { "license": "MIT", "description": "pkg v2" })
	update_conandata(run_script, package_directory, conandata_path, "2.0")

	conandata = load_yaml(conandata_path)

	assert conandata["common_attributes"] == { "license": "MIT" }
	assert conandata["attributes"] == {
		"1.0": { "description": "pkg" },
		"2.0": { "description": "pkg v2" },
	}
	assert list(conandata["sources"].keys()) == ["1.0", "2.0"]

def test_cli_replaces_existing_version(tmp_path, package_directory, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_directory, conandata_path, "1.0")
	write_package_info(package_directory, { "license": "MIT", "description": "changed" })
	update_conandata(run_script, package_directory, conandata_path, "1.0")

	conandata = load_yaml(conandata_path)

	assert conandata["common_attributes"] == { "license": "MIT", "description": "changed" }
	assert "attributes" not in conandata
	assert list(conandata["sources"].keys()) == ["1.0"]

def test_cli_sets_recipe_url(tmp_path, package_directory, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_directory, conandata_path, "1.0", "--recipe-url", "https://example.com/index")
	update_conandata(run_script, package_directory, conandata_path, "2.0", "--recipe-url", "https://example.com/index")

	conandata = load_yaml(conandata_path)

	assert conandata["common_attributes"] == { "license": "MIT", "description": "pkg", "url": "https://example.com/index" }
	assert "attributes" not in conandata

def test_cli_mismatched_name_fails(tmp_path, package_directory, run_script):
	conandata_path = tmp_path / "conandata.yml"

	update_conandata(run_script, package_directory, conandata_path, "1.0")
	result = update_conandata(run_script, package_directory, conandata_path, "2.0", name="other", check=False)

	assert result.returncode != 0
	assert "Mismatched package name" in result.stderr
