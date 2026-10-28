import yaml

from update_recipe_config import update_recipe_config


def test_update_recipe_config_creates_config():
	assert update_recipe_config(None, "1.0.0", "v1") == { "versions": { "1.0.0": { "folder": "v1" } } }

def test_update_recipe_config_adds_version():
	config = { "versions": { "1.0.0": { "folder": "all" } } }

	assert update_recipe_config(config, "2.0.0", "v1") == {
		"versions": { "1.0.0": { "folder": "all" }, "2.0.0": { "folder": "v1" } },
	}

def test_update_recipe_config_replaces_version():
	config = { "versions": { "1.0.0": { "folder": "all" } } }

	assert update_recipe_config(config, "1.0.0", "v1") == { "versions": { "1.0.0": { "folder": "v1" } } }


def test_cli_creates_and_updates_file(tmp_path, run_script):
	config_path = tmp_path / "config.yml"

	run_script("update_recipe_config.py", "--version", "1.0.0", "--folder", "v1", config_path)
	run_script("update_recipe_config.py", "--version", "2.0.0", "--folder", "v1", config_path)

	with open(config_path, "r") as file:
		assert yaml.safe_load(file) == {
			"versions": { "1.0.0": { "folder": "v1" }, "2.0.0": { "folder": "v1" } },
		}
