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

cd src
. ../../lib/rmake-common

set -x
server=$(rmake-resource-server testos)
buildroot=$(rmake-fixhomepath "$(rmake-resource-buildroot testos)")
buildroot=${buildroot%/}
buildrootex=$(rmake-fixhomepathex "$(rmake-resource-buildroot testos)")
buildrootex=${buildrootex%/}

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

rm -rf build-source build

(
set -e

svn revert module/hello.cpp
svn revert Makefile
svn revert module/Makefile

echo rmake-check
rmake -p testos -c
rmake -a -c

echo update only
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	rm -rf ${buildroot}-source
	rm -rf ${buildroot}
EOF

rmake -p testos -uv
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" = \$(find -name "*.svn*" | wc -l) ]

	cd ${buildroot}
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" = \$(find -name "*.svn*" | wc -l) ]
EOF

echo relative update
echo "test:" >> Makefile
echo "test2:" >> module/Makefile
rmake -p testos -C module -Ru
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
	! grep "test:" Makefile
	grep "test2:" module/Makefile

	cd ${buildroot}
	! grep "test:" Makefile
	grep "test2:" module/Makefile
EOF

svn revert Makefile
svn revert module/Makefile
touch module/hello.cpp
rmake -p testos -C module -Ru
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}
	test -f module/hello.cpp
EOF

echo make
rmake -a
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
	[ "0" = \$(find -links 1 | wc -l) ]
	cd ${buildroot}
	[ "3" = \$(find -links 1 | wc -l) ]
	test -f module/hello
	test -f root-file
EOF
test -f /tmp/rmake-$USER/testos.log

echo -RD with -C
rmake -C module -aRD
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
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

echo -D with -C
rmake -C module -aD
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
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

echo --pedantic
touch module/new.cpp
rmake -au
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
	test -f module/new.cpp

	cd ${buildroot}
	test -f module/new.cpp
EOF

rmake -au --pedantic
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
	test ! -f module/new.cpp

	cd ${buildroot}
	test ! -f module/new.cpp
EOF
rm module/new.cpp

echo --svn-meta
rm -rf ../build
rmake -p testos -uv --svn-meta
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}-source
	test -d module
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" != \$(find -name "*.svn*" | wc -l) ]

	cd ${buildroot}
	test -d module
	test -d module
	test -f Makefile
	test -f module/Makefile
	test -f module/hello.cpp
	[ "0" = \$(find -links 1 | wc -l) ]
	[ "0" != \$(find -name "*.svn*" | wc -l) ]
EOF

echo --svn-base
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	rm -rf ${buildroot}
EOF
! grep error module/hello.cpp
echo error >> module/hello.cpp

rmake -p testos -uv
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}
	grep error module/hello.cpp
EOF
rmake -p testos -uv --svn-base --debug
$(rmake-shell $server) <<-EOF
	set -x
	set -e

	cd ${buildroot}
	! grep error module/hello.cpp
EOF

svn revert -R module/hello.cpp
rm -rf ../build
mkdir ../build

)

result=$?
set +x

if [ 0 != $result ]; then
	echo Failed.
	exit 1
else
	echo Passed.
	exit 0
fi

