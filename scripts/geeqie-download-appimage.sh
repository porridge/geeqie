#!/bin/sh
#**********************************************************************
# Copyright (C) 2023 - The Geeqie Team
#
# Author: Colin Clark
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#**********************************************************************

## @file
## @brief Download full and minimal AppImages from the Continuous build release on GitHub.
## Optionally extract the full size AppImage.
##
## The user may modify the symbolic links as appropriate.
##
## Downloads will not be made unless the server version is newer than the local file.
##

version="2023-09-08"
backups=3

show_help()
{
	printf "Download the latest Geeqie AppImages from the
Continuous Build release on GitHub.

-b --backups <n> Set number of backups (default is 3)
-d --desktop Install desktop icon and menu item
-e --extract Extract AppImage
-h --help Display this message
-m --minimal Download minimal version of AppImage
-r --revert <n> Revert to downloaded AppImage backup
-v --version Display version of this file

The Continuous Build release is updated each
time the source code is updated.

The default action is to download an AppImage to
\$HOME/bin. A symbolic link will be set so that
\"geeqie\" points to the executable

No downloads will be made unless the file on the
server at GitHub is newer than the local file.

The full size AppImage is about 120MB and the
minimal AppImage is about 10MB. Therefore the full
size version will load much slower and will have
a slightly slower run speed.

However the minimal version has limited capabilities
compared to the full size version.

The minimal option (-m or --minimal) will download
the minimal version.

The extract option (-e or --extract) will extract
The contents of the AppImage into a sub-directory
of \$HOME/bin, and then set the symbolic link to the
extracted executable.

This will take up some disk space, but the
extracted executable will run as fast as a
packaged release.
\n\n"
}

show_version()
{
	printf "Version: %s\n" "$version"
}

architecture=$(arch)

extract=0
minimal=""
desktop=0
backups_option=0
revert=0
revert_option=0

while :
do
	case $1 in
		-h | -\? | --help)
			show_help

			exit 0
			;;
		-v | --version)
			show_version

			exit 0
			;;
		-d | --desktop)
			desktop=1
			;;
		-b | --backups)
			backups_option=1
			if [ -n "$2" ]
			then
				backups=$2
				shift
			else
				printf '"--backups" requires a non-empty option argument.\n' >&2

				exit 1
			fi
			;;
		-r | --revert)
			revert_option=1
			if [ -n "$2" ]
			then
				revert=$2
				shift
			else
				printf '"--revert" requires a non-empty option argument.\n' >&2

				exit 1
			fi
			;;
		-e | --extract)
			extract=1
			;;
		-m | --minimal)
			minimal="-minimal"
			;;
		--) # End of all options.
			shift
			break
			;;
		?*)
			printf 'Unknown option %s\n' "$1" >&2

			exit 1
			;;
		*)
			break
			;;
	esac

	shift
done

if [ ! -d "$HOME/bin" ]
then
	printf "\$HOME/bin does not exist.
It is required for this script to run.\n"

	exit 1
fi

cd "$HOME/bin/" || exit 1

if [ "$backups_option" -eq 1 ] && {
	[ "$minimal" = "-minimal" ] || [ "$extract" -eq 1 ] || [ "$revert_option" -eq 1 ]
}
then
	printf "backups must be the only option\n"

	exit 1
fi

if [ "$desktop" -eq 1 ] && {
	[ "$minimal" = "-minimal" ] || [ "$extract" -eq 1 ]
}
then
	printf "desktop must be the only option\n"

	exit 1
fi

if [ "$backups_option" -eq 1 ]
then
	if ! [ "$backups" -gt 0 ] 2> /dev/null
	then
		printf "%s is not an integer\n" "$backups"

		exit 1
	else
		tmp_file=$(mktemp "${TMPDIR:-/tmp}/geeqie.XXXXXXXXXX")
		cp "$0" "$tmp_file"
		sed --in-place "s/^backups=.*/backups=$backups/" "$tmp_file"
		chmod +x "$tmp_file"
		mv "$tmp_file" "$0"

		exit 0
	fi
fi

if [ "$desktop" -eq 1 ]
then
	if [ -f "$HOME/Desktop/geeqie.desktop" ]
	then
		printf "Desktop file already exists\n"

		exit 0
	fi

	file_count=$(find "$HOME/bin/" -name "Geeqie*latest*\.AppImage" -print | wc -l)
	if [ "$file_count" -eq 0 ]
	then
		printf "No AppImages have been downloaded\n"

		exit 1
	fi

	tmp_dir=$(mktemp --directory "${TMPDIR:-/tmp}/geeqie.XXXXXXXXXX")
	cd "$tmp_dir" || exit 1

	app=$(find "$HOME/bin/" -name "Geeqie*latest*\.AppImage" -print | sort --reverse | head -1)
	$app --appimage-extract "usr/local/share/applications/geeqie.desktop"
	$app --appimage-extract "usr/local/share/pixmaps/geeqie.png"
	xdg-desktop-icon install --novendor "squashfs-root/usr/local/share/applications/geeqie.desktop"
	xdg-icon-resource install --novendor --size 48 "squashfs-root/usr/local/share/pixmaps/geeqie.png"
	xdg-desktop-menu install --novendor "squashfs-root/usr/local/share/applications/geeqie.desktop"
	rm --recursive --force "$tmp_dir"

	exit 0
fi

if [ "$revert_option" -eq 1 ]
then
	if ! [ "$revert" -gt 0 ] 2> /dev/null
	then
		printf "%s is not an integer\n" "$revert"

		exit 1
	else
		if ! [ -f "$HOME/bin/Geeqie$minimal-latest-$architecture.AppImage.$revert" ]
		then
			printf "Backup $HOME/bin/Geeqie%s-latest-$architecture.AppImage.%s does not exist\n" "$minimal" "$revert"

			exit 1
		fi

		if [ "$extract" -eq 1 ]
		then
			rm --recursive --force "Geeqie$minimal-latest-$architecture-AppImage"
			mkdir "Geeqie$minimal-latest-$architecture-AppImage"
			cd "Geeqie$minimal-latest-$architecture-AppImage" || exit 1

			printf "Extracting AppImage\n"
			../"Geeqie$minimal-latest-$architecture.AppImage.$revert" --appimage-extract | cut --characters 1-50 | tr '\n' '\r'
			printf "\nExtraction complete\n"

			cd ..
			ln --symbolic --force "./Geeqie$minimal-latest-$architecture-AppImage/squashfs-root/AppRun" geeqie
		else
			ln --symbolic --force "$HOME/bin/Geeqie$minimal-latest-$architecture.AppImage.$revert" geeqie
		fi

		exit 0
	fi
fi

log_file=$(mktemp "${TMPDIR:-/tmp}/geeqie.XXXXXXXXXX")

wget --no-verbose --show-progress --backups="$backups" --output-file="$log_file" --timestamping "https://github.com/BestImageViewer/geeqie/releases/download/continuous/Geeqie$minimal-latest-$architecture.AppImage"

download_size=$(stat --printf "%s" "$log_file")
rm "$log_file"

# If a new file was downloaded, check if extraction is required
if [ "$download_size" -gt 0 ]
then
	chmod +x "Geeqie$minimal-latest-$architecture.AppImage"

	if [ "$extract" -eq 1 ]
	then
		rm --recursive --force "Geeqie$minimal-latest-$architecture-AppImage"
		mkdir "Geeqie$minimal-latest-$architecture-AppImage"
		cd "Geeqie$minimal-latest-$architecture-AppImage" || exit 1

		printf "Extracting AppImage\n"
		../"Geeqie$minimal-latest-$architecture.AppImage" --appimage-extract | cut --characters 1-50 | tr '\n' '\r'
		printf "\nExtraction complete\n"

		cd ..
		ln --symbolic --force "./Geeqie$minimal-latest-$architecture-AppImage/squashfs-root/AppRun" geeqie
	else
		ln --symbolic --force "Geeqie$minimal-latest-$architecture.AppImage" geeqie
	fi
fi
