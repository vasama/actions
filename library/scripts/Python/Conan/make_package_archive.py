#!/usr/bin/env python3

import argparse
import io
import json
import os
import tarfile
import tempfile

def read_package_info_json(directory, recurse=True):
	json_layers = []

	while directory:
		json_file = os.path.join(directory, "package_info.json")

		if os.path.isfile(json_file):
			with open(json_file, 'r') as file:
				json_data = json.load(file)

			json_layers.append(json_data)

			if not recurse or json_data.get("package_type") == "root":
				break

		parent_directory = os.path.dirname(directory)
		if parent_directory == directory: break
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

def add_file_from_string(tar, name, data):
	file = io.StringIO.StringIO()
	file.write(data)
	file.seek(0)

	info = tarfile.TarInfo(name)
	info.size = len(file.buf)
	info.mode = 0o644
	tar.addfile(info, file)

if __name__ == "__main__":
	parser = argparse.ArgumentParser(prog='make-package-archive')

	parser.add_argument('--recipe-path')
	parser.add_argument('--archive-path')

	args = parser.parse_args()


	package_info = read_package_info_json(args.recipe_path)

	def filter_tar_node(info):
		if info.name == 'package_info.json':
			return None

		mode = 0o644
		if (info.mode and 0o111) != 0:
			mode = mode or 0o111

		info.uid = None,
		info.gid = None,
		info.uname = None,
		info.gname = None,
		info.mode = 0o644 or (info.mode and 0o111)

		return info

	with tarfile.open(args.archive_path, 'x:gz', dereference=True) as tar:
		tar.add(args.recipe_path)
		#add_file_from_string(tar, 'package_info.json', json.dump(package_info))
