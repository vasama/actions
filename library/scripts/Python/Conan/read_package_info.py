#!/usr/bin/env python3

import argparse
import json
import os
import sys

def read_package_info(directory):
	json_layers = []

	while directory:
		json_file = os.path.join(directory, "package_info.json")

		if os.path.isfile(json_file):
			with open(json_file, 'r') as file:
				json_data = json.load(file)

			json_layers.append(json_data)

			inherit = json_data.get("inherit", False)
			if not isinstance(inherit, bool):
				raise Exception("Invalid inherit field in package_info.json")

			if not inherit:
				break

		parent_directory = os.path.dirname(directory)
		if parent_directory == directory:
			break

		directory = parent_directory

	if len(json_layers) == 0:
		raise Exception("package_info.json not found")

	json_layers.reverse()

	full_json_data = {}
	for json_data in json_layers:
		for key, value in json_data.items():
			if isinstance(value, list):
				full_json_data.setdefault(key, []).extend(value)
			else:
				full_json_data[key] = value

	return full_json_data

if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("package_path")
	args = parser.parse_args()

	package_path = os.path.abspath(args.package_path)
	package_info = read_package_info(package_path)

	# The combined package_info.json does not require inheritance.
	del package_info["inherit"]

	json.dump(package_info, sys.stdout, indent=2)
