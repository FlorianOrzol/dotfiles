#!/bin/bash
#
#  _____
# |~>   |     _
# |_____|   ('v') 
# /:::::\  /{w w}\ 
#
# created by: Florian Orzol
# script to link the .config files to the home directory 


#    <')
# \_;( )

# get the directory of this script, not the directory it is called from and not the directory where the link is
DIR=$(dirname $(readlink -f $0))

# list directories from .config
config_dirs=$(find $DIR/.config -type d)

# cut the path to .config
config_dirs=$(echo -e "$config_dirs" | awk -F "$DIR/.config" '{print $2}')

#check if the directories exist in the home-config directory and create them if they don't
for dir in $config_dirs; do
    if [ ! -d "$HOME/.config$dir" ]; then
        mkdir -p "$HOME/.config$dir"
    fi
done

# list of files from .config with full path
config_files=$(find $DIR/.config -type f)


# Link the files to the home-config directory
for file in $config_files; do
    # cut the path to .config
    file=$(echo -e "$file" | awk -F "$DIR/.config" '{print $2}')
    ln -sf "$DIR/.config$file" "$HOME/.config$file"
done