#!/bin/bash
#
#  diff-text-docs - compare text-containing files in various formats
#
#  Copyright (C) 2014, 2017 Alexander Yermolenko <yaa.mbox@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

f1=${1:?Filename is required}
f2=${2:?Filename is required}
cmpprog=${3:-meld}
filter=${4:-"cat"}

die()
{
    local msg=${1:-"Unknown error"}
    hash zenity 2>/dev/null && \
        zenity --error --title "Error" --text "ERROR: $msg"
    echo "ERROR: $msg" 1>&2
    exit 1
}

goodbye()
{
    local msg=${1:-"Cancelled by user"}
    hash zenity 2>/dev/null && \
        zenity --warning --title "Goodbye!" --text "$msg"
    echo "INFO: $msg" 1>&2
    exit 1
}

require()
{
    local cmd=${1:?"Command name is required"}
    local extra_info=${2:+"\nNote: $2"}
    hash $cmd 2>/dev/null || die "$cmd not found$extra_info"
}

require xdg-mime "xdg-utils package"
require $cmpprog

tempdir=$( mktemp -d )
[ -d "$tempdir" ] || die "Temp dir has not been created."

diff_via_antiword()
{
    local f1orig=${1:?"Filename is required"}
    local f2orig=${2:?"Filename is required"}

    local f1wodir="1-$( basename "$f1" )"
    local f2wodir="2-$( basename "$f2" )"

    local f1="$tempdir/$f1wodir"
    local f2="$tempdir/$f2wodir"

    cp "$f1orig" "$f1" || die "Cannot copy first file"
    cp "$f2orig" "$f2" || die "Cannot copy second file"

    local f1doc="$tempdir/${f1wodir%.*}.doc"
    local f2doc="$tempdir/${f2wodir%.*}.doc"

    require soffice "LibreOffice"

    [ -f "$f1doc" ] \
        || soffice --headless --convert-to doc --outdir "$tempdir" "$f1"
    [ -f "$f2doc" ] \
        || soffice --headless --convert-to doc --outdir "$tempdir" "$f2"

    [ -f "$f1doc" ] || die "Cannot find first converted file : $f1doc"
    [ -f "$f2doc" ] || die "Cannot find second converted file : $f2doc"

    require antiword

    local f1txt="$f1doc.txt"
    local f2txt="$f2doc.txt"
    antiword -w 0 "$f1doc" > "$f1txt"
    antiword -w 0 "$f2doc" > "$f2txt"
    chmod ugo-w "$f1txt"
    chmod ugo-w "$f2txt"
    $cmpprog "$f1txt" "$f2txt"
    chmod ugo+w "$f1txt"
    chmod ugo+w "$f2txt"
    rm "$f1txt" "$f2txt" || die "Cannot remove temp files"
}

[ -f "$f1" ] || [ -d "$f1" ] \
    || die "$f1 is not a file/directory or does not exist."
[ -f "$f2" ] || [ -d "$f2" ] \
    || die "$f2 is not a file/directory or does not exist."

mimetype=$(xdg-mime query filetype "$f1" | sed 's/;.*$//')
if [[ $mimetype == application/msword \
            || $mimetype =~ application/.*ms-word \
            || $mimetype =~ application/.*officedocument \
            || $mimetype =~ application/.*opendocument.text ]]; then
    diff_via_antiword "$f1" "$f2"
elif [[ -d "$f1" ]]; then
    $cmpprog "$f1" "$f2"
else
    mimetype1=$(xdg-mime query filetype "$f1" | sed 's/;.*$//')
    mimetype2=$(xdg-mime query filetype "$f2" | sed 's/;.*$//')

    zfilter1=cat
    [[ $mimetype1 == application/x-xz ]] && zfilter1="xz -cd -"
    [[ $mimetype1 == application/gzip ]] && zfilter1="gzip -cd -"
    [[ $mimetype1 == application/x-bzip ]] && zfilter1="bzip2 -cd -"
    zfilter2=cat
    [[ $mimetype2 == application/x-xz ]] && zfilter2="xz -cd -"
    [[ $mimetype2 == application/gzip ]] && zfilter2="gzip -cd -"
    [[ $mimetype2 == application/x-bzip ]] && zfilter2="bzip2 -cd -"

    if [[ $filter == cat && $zfilter1 == cat && $zfilter2 == cat ]]; then
        $cmpprog "$f1" "$f2"
    else
        $cmpprog <(cat "$f1" | $zfilter1 | $filter) <(cat "$f2" | $zfilter2 | $filter)
    fi
fi
