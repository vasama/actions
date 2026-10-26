import json
import os
import subprocess
import sys

import pytest

SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), "..", "library", "scripts", "Python", "Conan")
SCRIPTS_DIR = os.path.abspath(SCRIPTS_DIR)

# Make the scripts importable as modules:
sys.path.insert(0, SCRIPTS_DIR)


def write_json(path, data):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w") as file:
		json.dump(data, file)

def write_package_info(directory, data):
	write_json(os.path.join(directory, "package_info.json"), data)


@pytest.fixture
def run_script():
	"""Run a script from the library as a separate process."""

	def run(name, *args, cwd=None, check=True):
		return subprocess.run(
			[sys.executable, os.path.join(SCRIPTS_DIR, name), *map(str, args)],
			cwd=cwd,
			check=check,
			capture_output=True,
			text=True)

	return run
