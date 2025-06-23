# !/usr/bin/env python3

""" Factorio mod deployement script
Just move you code in a separate Directory like .../Deploy/ModName
This will be your root/Workspace which is preset to "."
The script will create a tempDir in which it copies all files and folders
and then creates a zip file which is moved to ./_release_/Modname_version.zip
if deploy_mod is true the zipfiles will be copied to the deploy_dir which is preset to Factorio/mods.
All options can be changed to your liking.

version: 1.0.0
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
# # Blacklist
exclude = ["_release_", "_lib", "_testing.lua", "vscode", "workspace", "orig", "new",
  "_working", ".git", ".py", ".xcf", ".7z", "single", "multi", "shot_", "README.md",
  ".vs", "lua-format", "shot-"]

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
# # -----------------------------------

file_count = sum(len(files) for _, _, files in os.walk(workspace))
# sys.exit(-1)

text = " Generating files for: " + mod_title + " - version: " + version + " "
f_size = 0
print("\n"+text.center(len(text)+22, "-"))


def match_pattern(string):
    for e in exclude:
        if string.find(e) != -1:
            return True
    return False


def file_size(_size):
    power_labels = {0: '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
    n = 0
    while _size > 1024:
        _size /= 1024
        n += 1
    return round(_size, 2), power_labels[n]+'B'


# # ----------------------------------- COLLECTING
i = 0
for root, subdirs, files in os.walk(workspace):
    if match_pattern(root):
        continue
    for filename in files:
        if match_pattern(filename):
            continue

        file_path = os.path.join(root, filename)

        if os.path.isfile(file_path):
            fp = os.path.join(root, filename)
            f_size += os.path.getsize(fp)
            if verbose:
                print('File: %s \t %s' % (mod_name_full, filename))
            else:
                print("\rCollecting: [{0}/{1}]".format(i, file_count), end='')
                i += 1
            os.makedirs(os.path.join(
                zip_temp_dir, os.path.dirname(file_path[2:])), exist_ok=True)
            shutil.copy(file_path, os.path.join(
                zip_temp_dir, os.path.dirname(file_path[2:])))

f_size = file_size(f_size)
print("\rCollected: [{0}] ({1} {2})".format(file_count, f_size[0], f_size[1]))

# # ----------------------------------- ZIPING
if os.path.exists(zip_file):
    print("\n%s already exists." % zip_file)
    quest = input("[R]emove or [A]bort? ") if verbose == True else "r"
    if quest == "r" or quest == "R":
        os.remove(zip_file)
    else:
        shutil.rmtree(zip_temp_dir)
        sys.exit("\n\tScript aborted with '"+quest +
                 "'\n\tNo changes where made.\n")


print('\nCreating\t %s' % (zip_name), end='')
zipf = zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED)

for root, subdirs, files in os.walk(zip_temp_dir):
    for filename in files:
        f = os.path.join(root, filename)
        zipf.write(f)
zipf.close()

z_size = os.path.getsize(zip_name)
z_size = file_size(z_size)
print(" ({0} {1})".format(z_size[0], z_size[1]))

shutil.rmtree(zip_temp_dir)
os.makedirs(zip_file_path, exist_ok=True)
shutil.move(zip_name, zip_file_path)

if deploy_mod:
    print("Deploying\t %s\%s" % (deploy_dir, zip_name))
    shutil.copy(zip_file, deploy_dir)

success = " Release " + version + " completed "
print("\n"+success.center(len(text)+22, "-")+"\n")
