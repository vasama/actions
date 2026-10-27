#!/usr/bin/env python3

import argparse
import io
import json
import os
import subprocess
import tarfile

from read_package_info import read_package_info

def get_file_size(file):
	p = file.tell()
	file.seek(0, os.SEEK_END)
	size = file.tell()
	file.seek(p, os.SEEK_SET)
	return size

def get_tracked_files(path, ref):
	command = [
		"git",
		"-C", path,
		"ls-tree",
		"-r",
		"--format", "%(objectmode) %(objecttype) %(path)",
		ref
	]

	result = subprocess.run(
		command,
		check=True,
		capture_output=True,
		text=True)

	def parse_line(line):
		parts = line.split(' ', 2)

		object_mode = parts[0]
		object_type = parts[1]
		object_path = parts[2]

		if object_type != "blob":
			raise Exception(f"Unsupported git object type: {object_type}")

		return (object_path, object_mode)

	return [parse_line(line) for line in result.stdout.splitlines()]

def add_file_from_string(tar, name, data, mode=0o644):
	with io.BytesIO(data.encode()) as file:
		info = tarfile.TarInfo(name)
		info.size = get_file_size(file)
		info.mode = mode
		tar.addfile(info, file)

if __name__ == "__main__":
	parser = argparse.ArgumentParser()

	parser.add_argument('--package-path')
	parser.add_argument('--archive-path')
	parser.add_argument('--overwrite', action="store_true")

	args = parser.parse_args()

	package_info = read_package_info(os.path.abspath(args.package_path))

	# The combined package_info.json does not require inheritance.
	package_info.pop("inherit", None)

	tracked_files = get_tracked_files(args.package_path, "HEAD")

	open_mode = f"{'w' if args.overwrite else 'x'}:gz"
	with tarfile.open(args.archive_path, open_mode, dereference=True) as tar:
		for path, mode in tracked_files:
			if path == "package_info.json":
				continue
		
			with open(os.path.join(args.package_path, path), 'rb') as file:
				info = tarfile.TarInfo(path)
				info.size = get_file_size(file)
				info.mode = int(mode, 8) & 0o777

				tar.addfile(info, file)

		add_file_from_string(tar, "package_info.json", json.dumps(package_info))
