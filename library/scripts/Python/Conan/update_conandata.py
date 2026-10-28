#!/usr/bin/env python3

import argparse
import copy
import os
import sys
import yaml

from frozendict import frozendict, deepfreeze

from read_package_info import load_package_info


attribute_keys = {
	"license": "license",
	"authors": "author",
	"website": "homepage",
	"description": "description",
	"package_type": "package_type",
}

# Conan requirement for each requirement config in package_info.json.
# The arguments match those used by Conan's tool_requires and test_requires.
# A visible tool requirement is also a build requirement of the consumers.
# Requirements marked as testing are skipped when testing is disabled.
tool_arguments = { "build": True, "headers": False, "libs": False, "run": True, "visible": False }
requirement_configs = {
	"header-library": { "arguments": { "transitive_headers": True } },
	"source-library": {},
	"test-library": { "arguments": { "headers": True, "libs": True, "test": True, "visible": False }, "testing": True },
	"header-application": { "arguments": { **tool_arguments, "visible": True } },
	"source-application": { "arguments": tool_arguments },
	"test-application": { "arguments": tool_arguments, "testing": True },
}


def read_package_json(package_path):
	path = os.path.join(package_path, "package_info.json")

	if not os.path.isfile(path):
		raise RuntimeError("package_info.json not found")

	return load_package_info(path)

def make_package_conandata(package):
	data = dict()

	for package_key, data_key in attribute_keys.items():
		value = package.get(package_key)
		if value is not None: data[data_key] = value

	data_requirements = []
	for require in package.get("requirements", ()):
		reference = f"{require["package"]}/{require["version"]}"

		# The configs are validated by the package_info.json schema:
		configs = require.get("configs", "header-library")
		if isinstance(configs, str):
			configs = [configs]
		assert isinstance(configs, list)

		# Each config is a separate use of the requirement:
		build_contexts = set()
		for config in configs:
			data_config = requirement_configs.get(config)
			assert data_config is not None

			# Conan allows only one requirement per reference in each context:
			build_context = data_config.get("arguments", {}).get("build", False)
			if build_context in build_contexts:
				raise RuntimeError(f"Conflicting requirement configs for {reference}")
			build_contexts.add(build_context)

			data_requirements.append({ "reference": reference, **copy.deepcopy(data_config) })

	if len(data_requirements) != 0:
		data["requirements"] = data_requirements

	return data

def get_package_conandata(package_path):
	return make_package_conandata(read_package_json(package_path))


def get_ver_data(conandata, version):
	all_data = dict(conandata.get("common_attributes", {}))
	ver_data = conandata.get("attributes", {}).get(version, {})

	for key, value in ver_data.items():
		all_value = all_data.get(key)

		if all_value is None:
			all_data[key] = value
			continue

		if type(all_value) != type(value):
			raise RuntimeError(f"Mismatched type for '{key}' in version attributes")

		if isinstance(value, list):
			frozen_all_value = set(deepfreeze(x) for x in all_value)
			all_data[key] = all_value + [x for x in value if deepfreeze(x) not in frozen_all_value]
		else:
			all_data[key] = value

	return all_data

def merge_ver_data(ver_data):
	ver_data_dict = ver_data
	ver_data = list(ver_data.values())

	common_attributes = {}

	ver_keys_set = [frozenset(x.keys()) for x in ver_data]
	ver_keys_set = list(frozenset.intersection(*ver_keys_set))
	ver_keys_set.sort()

	for key in ver_keys_set:
		frozen_values = set(deepfreeze(x.get(key)) for x in ver_data)

		if len(frozen_values) == 1:
			shared_value = ver_data[0][key]
			if shared_value is not None:
				common_attributes[key] = shared_value
				for ver in ver_data: ver.pop(key, None)
		else:
			types = set(type(x.get(key)) for x in ver_data)

			if len(types) != 1:
				raise RuntimeError(f"Mismatched type for '{key}' in version attributes")

			if types.pop() is list:
				shared = set.intersection(*(set(deepfreeze(y) for y in x[key]) for x in ver_data))

				if len(shared) != 0:
					common_attributes[key] = [x for x in ver_data[0][key] if deepfreeze(x) in shared]

					for ver in ver_data:
						ver_list = [x for x in ver[key] if deepfreeze(x) not in shared]

						if len(ver_list) == 0: del ver[key]
						else: ver[key] = ver_list

	for k, v in list(ver_data_dict.items()):
		if len(v) == 0:
			del ver_data_dict[k]

	return common_attributes


if __name__ == "__main__":
	parser = argparse.ArgumentParser()

	parser.add_argument('--source')

	parser.add_argument('--name')
	parser.add_argument('--version')

	parser.add_argument('--src-url')
	parser.add_argument('--src-hash')

	parser.add_argument('--recipe-url')

	parser.add_argument('conandata')

	args = parser.parse_args()


	data = None
	if os.path.isfile(args.conandata):
		with open(args.conandata, "r") as file:
			data = yaml.safe_load(file)
	if data is None: data = {}

	if args.name is not None:
		if data.setdefault("name", args.name) != args.name:
			raise RuntimeError(f"Mismatched package name: '{data["name"]}'")

	package_path = os.getcwd() if args.source is None else args.source
	ver_data = { v: get_ver_data(data, v) for v in data.get("sources", {}).keys() }
	ver_data[args.version] = get_package_conandata(package_path)

	if args.recipe_url is not None:
		ver_data[args.version]["url"] = args.recipe_url

	all_data = merge_ver_data(ver_data)

	if len(all_data) != 0:
		data["common_attributes"] = all_data
	else:
		data.pop("common_attributes", None)

	if len(ver_data) != 0:
		data["attributes"] = ver_data
	else:
		all_ver_data = data.get("attributes", {})
		all_ver_data.pop(args.version, None)

		if len(all_ver_data) == 0:
			data.pop("attributes", None)

	data_sources = data.setdefault("sources", {})
	data_sources[args.version] = { "url": args.src_url, "sha256": args.src_hash }

	with open(args.conandata, "w") as file:
		yaml.safe_dump(data, stream=file, default_flow_style=False, sort_keys=False)
