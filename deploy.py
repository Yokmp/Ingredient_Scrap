# !/usr/bin/env python3

""" Factorio mod deployement script
Just move you code in a separate Directory like .../Deploy/ModName
This will be your root/Workspace which is preset to "."
The script will create a tempDir in which it copies all files and folders
and then creates a zip file which is moved to ./_release_/Modname_version.zip
if deploy_mod is true the zipfiles will be copied to the deploy_dir which is preset to Factorio/mods.
All options can be changed to your liking.

version: 1.0.1
source: https://github.com/Yokmp/Factorio-Scripts
author: Yokmp
"""

import os
import sys
import shutil
import zipfile
import json
import platform
import getopt

# region ----------------------------------- Boring Settings
deploy_mod = False      # create a zip file or not
verbose = False     # print processed files
strip_debug_regions = True

# Release filtering. Keep this explicit so local tooling and generated debug
# artifacts do not accidentally ship with the production mod.
exclude_dirs = {
    "_release_",
    "_lib",
    "_working",
    ".agents",
    ".codex",
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".vs",
    ".vscode",
    "__pycache__",
    "lua-format",
    "orig",
    "new",
    "old",
    "single",
    "multi",
    "test",
    "tools",
    "workspace",
}
exclude_files = {
    ".gitattributes",
    ".gitignore",
    ".luarc.json",
    "DESIGN_NOTES.md",
    "locale/en/test.cfg",
}
exclude_extensions = {
    ".7z",
    ".py",
    ".pyc",
    ".pyo",
    ".xcf",
}
exclude_name_prefixes = (
    "shot_",
    "shot-",
)
exclude_name_contains = (
    "_testing.lua",
)

# # Get information from filesystem
workspace = "."
user_dir = os.path.expanduser('~')
deploy_dir = ""
release_dir = "_release_"
mod_name = ""
mod_title = ""
version = ""

# # Path settings - deploy_dir should end in factorio/mods so a new version can be tested easily
if platform.system() == "Windows":
    # deploy_dir = os.path.join(user_dir, "AppData", "Roaming", "Factorio", "mods")
    deploy_dir = os.path.join("F:\\", "Games", "Factorio_ModTest", "mods")
    # deploy_dir = os.path.join("F:\\", "Games", "Factorio_Latest", "mods")
else:
    deploy_dir = os.path.join(user_dir, ".factorio", "mods")
# endregion -----------------------------------

if not os.path.exists(deploy_dir):
    print("\nNo Factorio mod directory found. Aborting.")
    sys.exit(-1)

# # Get informations from info.json TODO: update json depending on user settings
with open("info.json") as info:
    js = json.load(info)
    version = js["version"] if version == "" else version
    mod_name = js["name"] if mod_name == "" else mod_name
    mod_title = js["title"] if mod_title == "" else mod_title

if (mod_name == ""):
    print("\nNo name found. Aborting.")
    sys.exit(-1)

if (mod_title == ""):
    print("\nNo title found. Aborting.")
    sys.exit(-1)

if (version == ""):
    print("\nNo version found. Aborting.")
    sys.exit(-1)

# # ----------------------------------- Arguments
arg = sys.argv[1:]
try:
    opts, args = getopt.getopt(arg, "vd:", ["version = "])
except getopt.GetoptError:
    print("Usage:\t%s -d:bool -v" % os.path.basename(__file__))
    print("%s -d\tbool\t - Deploy Mod or not " % os.path.basename(__file__))
    print("%s -v\t\t - verbose: show processed files and override any existing file without prompt" % os.path.basename(__file__))
    sys.exit(2)

for opt, arg in opts:
    if opt == "-d":
        if (arg == "true" or arg == "True"):
            deploy_mod = True
        elif (arg == "false" or arg == "False"):
            deploy_mod = False
        else:
            print(
                "%s -d\tbool - Deploy Mod, False will override any existing file without prompt" % sys.argv[0])
    elif opt == "-v":
        verbose = True

# # ----------------------------------- Secret Settings
mod_name_full = mod_name + "_" + version
mod_deploy_dir = os.path.join(deploy_dir, mod_name_full)
zip_name = mod_name_full + '.zip'
zip_file_path = os.path.join(workspace, release_dir)
zip_file = os.path.join(zip_file_path, mod_name + "_" + version+".zip")
zip_temp_dir = os.path.join(workspace, mod_name_full)
public_source_dir = os.path.join(workspace, release_dir, "public", mod_name)
# # -----------------------------------

file_count = sum(len(files) for _, _, files in os.walk(workspace))
# sys.exit(-1)

text = " Generating files for: " + mod_title + " - version: " + version + " "
f_size = 0
print("\n"+text.center(len(text)+22, "-"))


def release_relpath(path):
    return os.path.relpath(path, workspace).replace("\\", "/")


def remove_workspace_tree(path):
    workspace_abs = os.path.abspath(workspace)
    path_abs = os.path.abspath(path)
    if path_abs == workspace_abs or not path_abs.startswith(workspace_abs + os.sep):
        raise RuntimeError("Refusing to remove path outside workspace: %s" % path)
    if os.path.exists(path):
        shutil.rmtree(path)


def should_exclude_path(path, is_dir=False):
    relpath = release_relpath(path)
    if relpath == ".":
        return False

    parts = relpath.split("/")
    name = parts[-1]

    if any(part in exclude_dirs for part in parts):
        return True
    if relpath in exclude_files:
        return True
    if name.startswith(exclude_name_prefixes):
        return True
    if any(fragment in name for fragment in exclude_name_contains):
        return True
    if os.path.splitext(name)[1] in exclude_extensions:
        return True
    if is_dir and name == mod_name_full:
        return True
    return False


def file_size(_size):
    power_labels = {0: '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
    n = 0
    while _size > 1024:
        _size /= 1024
        n += 1
    return round(_size, 2), power_labels[n]+'B'


def strip_lua_debug_regions(text, source_path):
    lines = text.splitlines(keepends=True)
    output = []
    depth = 0
    removed = 0
    for line in lines:
        if line.strip() == "--#region debug":
            depth += 1
            removed += 1
            continue
        if line.strip() == "--#endregion":
            if depth == 0:
                raise RuntimeError("Unmatched debug region end in %s" % source_path)
            depth -= 1
            continue
        if depth == 0:
            output.append(line)
    if depth != 0:
        raise RuntimeError("Unclosed debug region in %s" % source_path)
    return "".join(output), removed


def copy_release_file(source_path, target_dir):
    if strip_debug_regions and source_path.endswith(".lua"):
        try:
            with open(source_path, "r", encoding="utf-8") as handle:
                text = handle.read()
            stripped, removed = strip_lua_debug_regions(text, source_path)
            if removed > 0 and stripped.strip() == "":
                if verbose:
                    print("Skipped empty stripped file: %s" % source_path)
                return False
            os.makedirs(target_dir, exist_ok=True)
            with open(os.path.join(target_dir, os.path.basename(source_path)), "w", encoding="utf-8", newline="") as handle:
                handle.write(stripped)
            return True
        except UnicodeDecodeError:
            pass
    os.makedirs(target_dir, exist_ok=True)
    shutil.copy(source_path, target_dir)
    return True


# # ----------------------------------- COLLECTING
if os.path.exists(zip_temp_dir):
    remove_workspace_tree(zip_temp_dir)

if os.path.exists(public_source_dir):
    remove_workspace_tree(public_source_dir)

i = 0
collected_count = 0
for root, subdirs, files in os.walk(workspace):
    subdirs[:] = [subdir for subdir in subdirs if not should_exclude_path(os.path.join(root, subdir), True)]
    if should_exclude_path(root, True):
        continue
    for filename in files:
        if should_exclude_path(os.path.join(root, filename)):
            continue

        file_path = os.path.join(root, filename)

        if os.path.isfile(file_path):
            fp = os.path.join(root, filename)
            if verbose:
                print('File: %s \t %s' % (mod_name_full, filename))
            else:
                print("\rCollecting: [{0}/{1}]".format(i, file_count), end='')
            copied = copy_release_file(
                file_path,
                os.path.join(public_source_dir, os.path.dirname(file_path[2:]))
            )
            if copied:
                f_size += os.path.getsize(os.path.join(
                    public_source_dir,
                    os.path.dirname(file_path[2:]),
                    os.path.basename(file_path)
                ))
                collected_count += 1
            i += 1

f_size = file_size(f_size)
print("\rCollected: [{0}] ({1} {2})".format(collected_count, f_size[0], f_size[1]))
print("Public source:\t %s" % public_source_dir)

# # ----------------------------------- ZIPING
if os.path.exists(zip_file):
    print("\n%s already exists." % zip_file)
    quest = input("[R]emove or [A]bort? ") if verbose == True else "r"
    if quest == "r" or quest == "R":
        os.remove(zip_file)
    else:
        remove_workspace_tree(zip_temp_dir)
        sys.exit("\n\tScript aborted with '"+quest +
                 "'\n\tNo changes where made.\n")


print('\nCreating\t %s' % (zip_name), end='')
shutil.copytree(public_source_dir, zip_temp_dir)
zipf = zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED)

for root, subdirs, files in os.walk(zip_temp_dir):
    for filename in files:
        f = os.path.join(root, filename)
        zipf.write(f)
zipf.close()

z_size = os.path.getsize(zip_name)
z_size = file_size(z_size)
print(" ({0} {1})".format(z_size[0], z_size[1]))

remove_workspace_tree(zip_temp_dir)
os.makedirs(zip_file_path, exist_ok=True)
shutil.move(zip_name, zip_file_path)

if deploy_mod:
    print("Deploying\t %s\%s" % (deploy_dir, zip_name))
    shutil.copy(zip_file, deploy_dir)

success = " Release " + version + " completed "
print("\n"+success.center(len(text)+22, "-")+"\n")
