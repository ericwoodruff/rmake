#! /bin/bash

# Copyright (c) 2008-2010 Hewlett-Packard Development Company, L.P.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
# Author: Eric Woodruff <eric dot woodruff at gmail.com>

RMAKE_HOME="$(dirname "$(readlink -en "${BASH_SOURCE}")")"
RMAKERC=~/.rmakerc

if [ -f $RMAKERC ]; then
	. $RMAKERC
fi

# Callback for rmake -x to email build results
# only on failure
# $1: platform
# $2: exit code from the build
# $3: timestamp
# $4: the build resource
# $5: build log (if any)
platform=$1
result=$2
timestamp="$3"
resource="$4"
logfile="$5"

if [ 0 -ne $2 ]; then
	$RMAKE_HOME/rmake-email.sh "$@"
fi
