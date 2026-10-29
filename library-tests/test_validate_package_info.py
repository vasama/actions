import os

from conftest import write_package_info
from validate_package_info import validate_package_info


def test_valid_files(tmp_path):
	write_package_info(tmp_path, { "license": "MIT" })
	write_package_info(tmp_path / "pkg", { "inherit": True, "package_type": "static-library" })

	assert validate_package_info([
		str(tmp_path / "package_info.json"),
		str(tmp_path / "pkg" / "package_info.json"),
	]) == []

def test_no_files():
	assert validate_package_info([]) == []

def test_schema_violation(tmp_path):
	write_package_info(tmp_path, { "package_type": "library" })

	errors = validate_package_info([str(tmp_path / "package_info.json")])

	assert len(errors) == 1
	assert "Invalid" in errors[0]

def test_inherit_without_parent(tmp_path):
	write_package_info(tmp_path, { "inherit": True })

	errors = validate_package_info([str(tmp_path / "package_info.json")])

	assert len(errors) == 1
	assert "Inherited package_info.json not found" in errors[0]

def test_invalid_inherited_file(tmp_path):
	write_package_info(tmp_path, { "license": 1 })
	write_package_info(tmp_path / "pkg", { "inherit": True })

	errors = validate_package_info([str(tmp_path / "pkg" / "package_info.json")])

	assert len(errors) == 1

def test_reports_every_invalid_file(tmp_path):
	write_package_info(tmp_path / "a", { "license": 1 })
	write_package_info(tmp_path / "b", { "license": "MIT" })
	write_package_info(tmp_path / "c", { "version": 1 })

	errors = validate_package_info([
		str(tmp_path / name / "package_info.json") for name in ["a", "b", "c"]
	])

	assert len(errors) == 2


def test_cli_fails_on_invalid_file(tmp_path, run_script):
	write_package_info(tmp_path, { "license": 1 })

	result = run_script("validate_package_info.py", tmp_path / "package_info.json", check=False)

	assert result.returncode == 1
	assert "package_info.json" in result.stderr

def test_cli_succeeds_on_valid_file(tmp_path, run_script):
	write_package_info(tmp_path, { "license": "MIT" })

	run_script("validate_package_info.py", tmp_path / "package_info.json")
