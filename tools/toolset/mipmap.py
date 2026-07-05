# -*- coding: utf-8 -*-
# Python 3
#
# Thanks to Deadlock989 for sharing his script
# https://forums.factorio.com/viewtopic.php?f=69&t=93693
#
# You need the Pillow module for this script to work
# python -m pip install --upgrade Pillow
#
# version 1.0.0

from PIL import Image
import os, sys, math, platform, getopt, json


# # ----------------------------------- Presets
finput              = "graphics/_single/"
foutput             = "graphics/_multi/"
min_icon_size       = 32
max_icon_size       = 64
mipmap_levels       = 2
crop_image          = False
verbose             = False

# # ----------------------------------- Arguments
arg = sys.argv[1:]
try:
    opts, args = getopt.getopt(arg, "vcs:m:i:o:", ["in=", "out="])
except getopt.GetoptError:
    print("Usage:\t%s -v -c -s -m -i -o [--out=] [--in=]\n" % os.path.basename(__file__))
    print("%s -v\t\t - verbose " % os.path.basename(__file__))
    print("%s -c\t\t - crop canvas " % os.path.basename(__file__))
    print("%s -s\t\t - set icon size " % os.path.basename(__file__))
    print("%s -m\t\t - set mipmap amount " % os.path.basename(__file__))
    print("%s -i --in\t - input Folder " % os.path.basename(__file__))
    print("%s -o --out\t - output Folder " % os.path.basename(__file__))
    sys.exit(2)

for opt, arg in opts:
    if opt in "-v":
        verbose = True
    if opt in "-c":
        # try:
            crop_image = True
        # except:
            # print("\t-s\ttype error: integer expected. Aborting."); sys.exit(-1)
    if opt in "-s":
        try:
            max_icon_size = int(arg)
            max_icon_size = max_icon_size if max_icon_size % 2 == 0 else min_icon_size
            max_icon_size = max_icon_size if max_icon_size > min_icon_size else min_icon_size
        except:
            print("\t-s\ttype error: integer expected. Aborting"); sys.exit(-1)
    elif opt in "-m":
        try:
            mipmap_levels = int(arg)
            mipmap_levels = mipmap_levels if mipmap_levels > 0 else 1
        except:
            print("\t-s\ttype error: integer expected. Aborting."); sys.exit(-1)
    elif opt in ("-i", "--in"):
            if not os.path.exists(arg):
                print("Path %s doesn't exist. Aborting." %arg); sys.exit(-1)
            finput = arg
    elif opt in ("-o", "--out"):
            if not os.path.exists(arg):
                print("Path %s doesn't exist. Aborting." %arg); sys.exit(-1)
            foutput = arg


# # ----------------------------------- Format (just in case ...)
if platform.system() == "Windows":
    finput  = finput.replace("/", "\\")
    foutput = foutput.replace("/", "\\")
else:
    finput  = finput.replace("\\", "/")
    foutput = foutput.replace("\\", "/")


# # ----------------------------------- Cropping
def crop_canvas(old_image, size):
    old_image = old_image.crop(old_image.getbbox())
    old_width, old_height = old_image.size
    if old_width > size or old_height > size:
        largest = (old_width >= old_height) and old_width or old_height
        old_image = old_image.resize(
            (int(size*old_width/largest), int(size*old_height/largest)), Image.LANCZOS)
        old_width, old_height = old_image.size
    x1 = int(math.floor((size - old_width) / 2))
    y1 = int(math.floor((size - old_height) / 2))
    newImage = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    newImage.paste(old_image, (x1, y1, x1 + old_width, y1 + old_height))
    return newImage


# # ----------------------------------- Create Mipmap
def create_mipmap(outputf, inputf, size, levels):
    original = crop_canvas(Image.open(inputf), size) if crop_image else Image.open(inputf)
    mipmap = Image.new("RGBA", (int(size * ((1-0.5**levels)/0.5)), size), (0, 0, 0, 0))
    offset = 0
    for i in range(0, levels):
        new_size = int(size * (0.5**i))
        copy = original.resize((new_size, new_size), Image.LANCZOS)
        mipmap.paste(copy, box=(offset, 0))
        offset += new_size
    mipmap.save(outputf)


# # ----------------------------------- Size
def file_size(_size):
    power_labels = {0: '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
    n = 0
    while _size > 1024:
        _size /= 1024
        n += 1
    return round(_size, 2), power_labels[n]+'B'


# # ----------------------------------- Reading JSON
with open("info.json") as info:
    js = json.load(info)
    version = js["version"]
    mod_title = js["title"]

if (mod_title == ""):
    mod_title = "unknown mod"

if (version == ""):
    version = "?.?.?"


# # ----------------------------------- Loop over Files
file_count = sum(len(files) for _, _, files in os.walk(os.path.join(".",finput)))
# width = max_icon_size*(1-(1/2)**mipmap_levels)*2
width = math.floor(max_icon_size*1.875)
text = " Generating Mipmaps for: " + mod_title + " - version: " + version + " "
print("\n"+text.center(len(text)+20, "-"))

# print("\n"+text.center(len(text)+58, "-"))
print(" Mipmaps:{0:>2}\n Size:\t{1:>5}x{2}".format(mipmap_levels, width, max_icon_size))
print(" Files:{0:>4}\n".format(file_count))

i = 1
if verbose: print("Generating:")
for root, dirs, files in os.walk(finput):
    for filename in files:
        if ".png" in filename:
            fp = os.path.join(root, filename)
            f_size = file_size(os.path.getsize(fp))
            if verbose:
                print(" {0}: {1} \t {2} {3}".format(i, filename, f_size[0], f_size[1]))
            else:
                print("\rGenerating: [{0}/{1}]".format(i, file_count), end='')
            
            create_mipmap(os.path.join(foutput, filename),
                          os.path.join(finput, filename),
                          max_icon_size, mipmap_levels )
            i+=1

success = " All mipmaps generated "
print("\n"+success.center(len(text)+20, "-")+"\n")