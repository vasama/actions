#!/usr/bin/env python3

import argparse
import json
import os
import sys

def read_package_info(directory):
	json_file = os.path.join(directory, "package_info.json")

	if not os.path.isfile(json_file):
		raise Exception("package_info.json not found")

	json_layers = []

	while True:
		with open(json_file, 'r') as file:
			json_data = json.load(file)

		json_layers.append(json_data)

		inherit = json_data.get("inherit", False)
		if not isinstance(inherit, bool):
			raise Exception("Invalid inherit field in package_info.json")

		if not inherit:
			break

		# Search the parent directories for the inherited package_info.json:
		while True:
			parent_directory = os.path.dirname(directory)
			if parent_directory == directory:
				raise Exception("Inherited package_info.json not found")

			directory = parent_directory
			json_file = os.path.join(directory, "package_info.json")

			if os.path.isfile(json_file):
				break

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
	if "inherit" in package_info:
		del package_info["inherit"]

	json.dump(package_info, sys.stdout, indent=2)
