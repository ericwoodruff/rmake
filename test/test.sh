#! /bin/bash

# Copyright (c) 2008-2010 Hewlett-Packard Development Company, L.P.
# Copyright (c) 2012 Eric Woodruff
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

dotsvn=""

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

function cleanup () {
	rm -rf build-snapshot build src repo
}

function run-tests () {
(
set +e
. ../../lib/rmake-common
server=$(rmake-resource-server testos)
buildroot=$(rmake-fixhomepath "$(rmake-resource-buildroot testos)")
buildroot=${buildroot%/}
buildrootex=$(rmake-fixhomepathex "$(rmake-resource-buildroot testos)")
buildrootex=${buildrootex%/}
set -e

echo
echo
echo 1$dotsvn rmake-check
rmake -p testos -c
rmake -a -c

echo
echo
echo 2$dotsvn update only
rmake-exec $server <<-EOF
	set -e

	rm -rf ${buildroot}-snapshot ${buildroot}
EOF

rmake -p testos -uv
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" = \$(find -name "*${dotsvn}*" | wc -l) ]

	cd ${buildroot}
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" = \$(find -name "*${dotsvn}*" | wc -l) ]
EOF

echo
echo
echo 3$dotsvn relative update
echo "test:" >> Makefile
echo "test2:" >> module/Makefile
rmake -p testos -C module -Ru
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	! grep -q "test:" Makefile
	grep -q "test2:" module/Makefile

	cd ${buildroot}
	! grep -q "test:" Makefile
	grep -q "test2:" module/Makefile
EOF

svn-revert Makefile
svn-revert module/Makefile
touch module/hello.cpp
rmake -p testos -C module -Ru
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}
	test -f module/hello.cpp
EOF

echo
echo
echo 4$dotsvn make
rmake -a
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	[ "0" = \$(find -links 1 | wc -l) ]
	cd ${buildroot}
	[ "3" = \$(find -links 1 | wc -l) ]
	test -f module/hello
	test -f root-file
EOF
test -f /tmp/rmake-$USER/testos.log

echo
echo
echo 5$dotsvn -RD with -C
rmake -C module -aRD
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]

	cd ${buildroot}
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "2" = \$(find -links 1 | wc -l) ]
	test ! -f module/hello
	test -f root-file
EOF

echo
echo
echo 6$dotsvn -D with -C
rmake -C module -aD
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]

	cd ${buildroot}
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
EOF

echo
echo
echo 7$dotsvn --pedantic
touch module/new.cpp
rmake -au
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	test -f module/new.cpp

	cd ${buildroot}
	test -f module/new.cpp
EOF

rmake -au --pedantic
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	test ! -f module/new.cpp

	cd ${buildroot}
	test ! -f module/new.cpp
EOF
rm module/new.cpp

echo
echo
echo 7$dotsvn --svn-meta
rm -rf ../build
rmake -p testos -uv --svn-meta
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}-snapshot
	test -d module
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" != \$(find -name "*${dotsvn}*" | wc -l) ]

	cd ${buildroot}
	test -d module
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" != \$(find -name "*${dotsvn}*" | wc -l) ]
EOF

echo
echo
echo 8$dotsvn --svn-base
rmake-exec $server <<-EOF
	set -e

	rm -rf ${buildroot}
EOF
! grep -q error module/hello.cpp
echo error >> module/hello.cpp

rmake -p testos -uv
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}
	grep -q error module/hello.cpp
EOF
rmake -p testos -uv --svn-base
rmake-exec $server <<-EOF
	set -e

	cd ${buildroot}
	! grep -q error module/hello.cpp
EOF
)

result=$?

if [ 0 != $result ]; then
	echo
	echo
	echo $dotsvn Failed.
	echo
	echo
	exit 1
else
	echo
	echo
	echo $dotsvn Passed.
	echo
	echo
fi
}

function svn-init () {
	dotsvn=".svn"
	mkdir repo
	svnadmin create repo
	svn checkout file://$PWD/repo src
	cp -r prototype/* prototype/.rmake* src/
	(cd src && svn add --force ./* && svn commit -m'add test files')
}

function svn-revert () {
	svn revert $1
}

set -e
cleanup
#svn-init
#(cd src && run-tests)

function svn-init () {
	dotsvn=".git"
	mkdir src
	(cd src && git init .)
	cp -r prototype/* prototype/.rmake* src/
	(cd src && git add . && git commit -m'add test files')
}

function svn-revert () {
	git reset HEAD $1 || true
	git checkout $1
}

cleanup
svn-init
(cd src && run-tests)

cleanup
