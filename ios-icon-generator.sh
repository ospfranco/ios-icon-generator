#!/bin/bash
#
# Copyright (C) 2018 smallmuou <smallmuou@163.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -e

spushd() {
     pushd "$1" 2>&1> /dev/null
}

spopd() {
     popd 2>&1> /dev/null
}

info() {
     local green="\033[1;32m"
     local normal="\033[0m"
     echo -e "[${green}INFO${normal}] $1"
}

cmdcheck() {
    command -v $1>/dev/null 2>&1 || { error >&2 "Please install command $1 first."; exit 1; }   
}

error() {
     local red="\033[1;31m"
     local normal="\033[0m"
     echo -e "[${red}ERROR${normal}] $1"
}

warn() {
     local yellow="\033[1;33m"
     local normal="\033[0m"
     echo -e "[${yellow}WARNING${normal}] $1"
}

yesno() {
    while true;do
    read -p "$1 (y/n)" yn
    case $yn in
        [Yy]) $2;break;;
        [Nn]) exit;;
        *) echo 'please enter y or n.'
    esac
done
}

curdir() {
    if [ ${0:0:1} = '/' ] || [ ${0:0:1} = '~' ]; then
        echo "$(dirname $0)"
    elif [ -L $0 ];then
        name=`readlink $0`
        echo $(dirname $name)
    else
        echo "`pwd`/$(dirname $0)"
    fi
}

myos() {
    echo `uname|tr "[:upper:]" "[:lower:]"`
}

#########################################
###           GROBLE DEFINE           ###
#########################################

VERSION=2.0.0
AUTHOR=smallmuou

#########################################
###             ARG PARSER            ###
#########################################

usage() {
prog=`basename $0`
cat << EOF
$prog version $VERSION by $AUTHOR

USAGE: $prog [OPTIONS] srcfile dstpath

DESCRIPTION:
    This script aim to generate iOS/macOS/watchOS APP icons more easier and simply.

    srcfile - The source png image. Preferably above 1024x1024
    dstpath - The destination path where the icons generate to.

OPTIONS:
    -h      Show this help message and exit

EXAMPLES:
    $prog 1024.png ~/123

EOF
exit 1
}

while getopts 'h' arg; do
    case $arg in
        h)
            usage
            ;;
        ?)
            # OPTARG
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))

[ $# -ne 2 ] && usage

#########################################
###            MAIN ENTRY             ###
#########################################

cmdcheck sips
src_file=$1
dst_path=$2

# check source file
[ ! -f "$src_file" ] && { error "The source file $src_file does not exist, please check it."; exit -1; }

# check width and height 
src_width=`sips -g pixelWidth $src_file 2>/dev/null|awk '/pixelWidth:/{print $NF}'`
src_height=`sips -g pixelHeight $src_file 2>/dev/null|awk '/pixelHeight:/{print $NF}'`

[ -z "$src_width" ] &&  { error "The source file $src_file is not a image file, please check it."; exit -1; }

if [ $src_width -ne $src_height ];then
    warn "The height and width of the source image are different, will cause image deformation."
fi

# create dst directory 
[ ! -d "$dst_path" ] && mkdir -p "$dst_path"

# ios sizes refer to https://developer.apple.com/design/human-interface-guidelines/ios/icons-and-images/app-icon/
# macos sizes refer to https://developer.apple.com/design/human-interface-guidelines/macos/icons-and-images/app-icon/
# watchos sizes refer to https://developer.apple.com/design/human-interface-guidelines/watchos/icons-and-images/home-screen-icons/
# 
# 
# name size
sizes_mapper=`cat << EOF
AppIcon16x16         16
AppIcon16x16@2x      32
AppIcon32x32         32
AppIcon32x32@2x      64
AppIcon128x128        128
AppIcon128x128@2x     256
AppIcon256x256        256
AppIcon256x256@2x     256
AppIcon512x512        512
AppIcon512x512@2x     1024
AppIcon20x20         20
AppIcon20x20~ipad         20
AppIcon20x20@2x      40
AppIcon20x20@2x~ipad      40
AppIcon20x20@3x      60
AppIcon29x29         29
AppIcon29x29~ipad         29
AppIcon29x29@2x      58
AppIcon29x29@2x~ipad      58
AppIcon29x29@3x      87
AppIcon40x40         40
AppIcon40x40~ipad         40
AppIcon40x40@2x      80
AppIcon40x40@2x~ipad      80
AppIcon40x40@3x      120
AppIcon60x60@2x      120
AppIcon60x60@3x      180
AppIcon76x76         76
AppIcon76x76~ipad         76
AppIcon76x76@2x      152
AppIcon76x76@2x~ipad      152
AppIcon83.5x83.5@2x    167
AppIcon83.5x83.5@2x~ipad    167
AppIcon1024x1024       1024
AppIcon24x24@2x      48
AppIcon27.5x27.5@2x    55
AppIcon86x86@2x      172
AppIcon98x98@2x      196
AppIcon108x108@2x     216
AppIcon44x44@2x      88
AppIcon50x50      50
AppIcon50x50~ipad      50
AppIcon57x57      57
AppIcon57x57@2x      114
AppIcon50x50@2x      100
AppIcon50x50@2x~ipad      100
AppIcon72x72@2x      144
AppIcon72x72~ipad      72
AppIcon72x72@2x~ipad      144
AppIcon72x72@3x      216
EOF`

OLD_IFS=$IFS
IFS=$'\n'
srgb_profile='/System/Library/ColorSync/Profiles/sRGB Profile.icc'

for line in $sizes_mapper
do
    name=`echo $line|awk '{print $1}'`
    size=`echo $line|awk '{print $2}'`
    info "Generate $name.png ..."
    if [ -f $srgb_profile ];then
        sips --matchTo '/System/Library/ColorSync/Profiles/sRGB Profile.icc' -z $size $size $src_file --out $dst_path/$name.png >/dev/null 2>&1
    else
        sips -z $size $size $src_file --out $dst_path/$name.png >/dev/null
    fi
done

info "Congratulation. All icons for iOS/macOS/watchOS APP are generate to the directory: $dst_path."

IFS=$OLD_IFS

