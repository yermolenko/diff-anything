#!/bin/bash
#
#  diff-git-repos - make a quick overview of differences between local
#  clones of a git repository
#
#  Copyright (C) 2017 Alexander Yermolenko <yaa.mbox@gmail.com>
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

date=`date "+%Y%m%d-%H%M%S"`

die()
{
    msg=${1:-"Unknown Error"}
    echo "ERROR: $msg" 1>&2
    exit 1
}

goodbye()
{
    msg=${1:-"Cancelled by user"}
    echo "INFO: $msg" 1>&2
    exit 1
}

info()
{
    msg=${1:-"Info"}
    echo "INFO: $msg" 1>&2
}

[ $# -ge 2 ] || die "Incorrect number of repos to compare."
repo1="$1"
repo2="$2"

[ -d "$repo1" ] || die "$1 is not a repo."
[ -d "$repo2" ] || die "$2 is not a repo."

tdir_base=`mktemp -d -t "diff-git-repos-XXXXXXXXXX"`

get_repo_log()
{
    [ $# -eq 2 ] || die "Incorrect number of repos."
    local repo="$1"
    local tdir="$tdir_base/$2"

    mkdir -p "$tdir" || die "Cannot create temp directories"

    pushd "$repo" >/dev/null 2>&1 || die "Cannot cd to git repo dir"

    git log --pretty=format:"%h - %an, %ad : %s" \
        > "$tdir/complete_log_wo_tags" 2> "$tdir/complete_log.err" \
        || die "Cannot get complete log"

    branches=()
    eval "$(git for-each-ref --shell --format='branches+=(%(refname))' refs/heads/ refs/tags)"
    for branch in "${branches[@]}"; do
        local safe_branch=$(echo "$branch" | sed -e 's/[^a-zA-Z0-9\-]/_/g')
        local logfile="$tdir/$safe_branch"
        touch "$logfile" || die "Cannot open output file"
        echo "====== $branch" > "$logfile"
        git log --pretty=format:"%h - %an, %ad : %s" "$branch" >> "$logfile"
    done

    popd >/dev/null 2>&1 || die "Cannot cd from git repo dir"
}

get_repo_log "$repo1" "1"
get_repo_log "$repo2" "2"

meld "$tdir_base/"* >/dev/null 2>&1

find "$tdir_base/1" -maxdepth 1 -type f -delete
find "$tdir_base/2" -maxdepth 1 -type f -delete
rmdir "$tdir_base/1"
rmdir "$tdir_base/2"
rmdir "$tdir_base"
