import os

import yaml


def make_recipe(root, name, versions):
	recipe_dir = os.path.join(root, "recipes", name)
	os.makedirs(recipe_dir)

	config = { "versions": { v: { "folder": f } for v, f in versions.items() } }
	with open(os.path.join(recipe_dir, "config.yml"), "w") as file:
		yaml.safe_dump(config, file)

	return recipe_dir


def test_prints_version_folder(tmp_path, run_script):
	recipe_dir = make_recipe(tmp_path, "vsm.core", { "1.0.0": "all", "2.0.0": "v2" })

	result = run_script("get_recipe_directory.py",
		"--root", tmp_path,
		"--name", "vsm.core",
		"--version", "2.0.0")

	assert result.stdout.strip() == os.path.join(recipe_dir, "v2")

def test_root_defaults_to_working_directory(tmp_path, run_script):
	recipe_dir = make_recipe(tmp_path, "vsm.core", { "1.0.0": "all" })
	os.mkdir(os.path.join(recipe_dir, "all"))

	result = run_script("get_recipe_directory.py",
		"--name", "vsm.core",
		"--version", "1.0.0",
		cwd=tmp_path)

	assert os.path.samefile(result.stdout.strip(), tmp_path / "recipes" / "vsm.core" / "all")

def test_unknown_version_fails(tmp_path, run_script):
	make_recipe(tmp_path, "vsm.core", { "1.0.0": "all" })

	result = run_script("get_recipe_directory.py",
		"--root", tmp_path,
		"--name", "vsm.core",
		"--version", "9.9.9",
		check=False)

	assert result.returncode != 0
