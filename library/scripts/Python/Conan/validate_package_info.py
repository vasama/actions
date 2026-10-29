#!/usr/bin/env python3

import argparse
import os
import sys

from read_package_info import read_package_info

def validate_package_info(json_files):
	errors = []
	for json_file in json_files:
		try:
			read_package_info(os.path.dirname(os.path.abspath(json_file)))
		except Exception as e:
			errors.append(f"{json_file}: {e}")
	return errors

if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("json_files", nargs="*")
	args = parser.parse_args()

	errors = validate_package_info(args.json_files)

	for error in errors:
		print(error, file=sys.stderr)

	if errors:
		sys.exit(1)
