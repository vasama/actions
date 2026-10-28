#!/usr/bin/env python3

import argparse
import os
import yaml

if __name__ == "__main__":
	parser = argparse.ArgumentParser()

	parser.add_argument("--index-path")
	parser.add_argument("--name")
	parser.add_argument("--version")

	args = parser.parse_args()

	index_path = os.getcwd() if args.index_path is None else args.index_path
	recipe_path = os.path.join(index_path, "recipes", args.name)

	with open(os.path.join(recipe_path, "config.yml"), "r") as file:
		recipe_config = yaml.safe_load(file)

	print(os.path.join(recipe_path, recipe_config["versions"][args.version]["folder"]))
