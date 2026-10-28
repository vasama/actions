#!/usr/bin/env python3

import argparse
import os
import yaml


# Adds or replaces a version in a local recipes index config.yml.
def update_recipe_config(config, version, folder):
	if config is None: config = {}
	config.setdefault("versions", {})[version] = { "folder": folder }
	return config


if __name__ == "__main__":
	parser = argparse.ArgumentParser()

	parser.add_argument("--version", required=True)
	parser.add_argument("--folder", required=True)

	parser.add_argument("config")

	args = parser.parse_args()

	config = None
	if os.path.isfile(args.config):
		with open(args.config, "r") as file:
			config = yaml.safe_load(file)

	config = update_recipe_config(config, args.version, args.folder)

	with open(args.config, "w") as file:
		yaml.safe_dump(config, stream=file, default_flow_style=False, sort_keys=False)
