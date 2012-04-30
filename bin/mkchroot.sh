#!/bin/bash

root=/centos
defaultport=23

export http_proxy=""

unset cmd
unset help
unset port
unset packages

OPT_ENV=$(getopt -o p:hx? \
	--long port:,help,root:,init,revert,start,stop \
	-n 'mkchroot.sh' -- "$@")

if [ $? != 0 ]; then
	help=1
fi

eval set -- "$OPT_ENV"

while true; do
	case "$1" in
		--help)
			help=1
			;;
		--init|--start|--stop|--revert)
			[ -z "${cmd}" ] || help=1
			cmd="${1#--}"
			;;
		-p|--port)
			port="$2"
			shift
			;;
		--root)
			root="$2"
			if [ "/" = "$root" ]; then
				echo "Invalid root: $root!"
				exit 1
			fi
			shift
			;;
		-x)
			set -x
			;;
		--)
			shift
			packages="$@"
			break
			;;
		*)
			help=1
			break
			;;

	esac
	shift
done

if [ -z "${cmd}" ]; then
	help=1
fi

if [ "init" != "${cmd}" ] && [ -n "$port" ]; then
	echo "--port requires --init"
	exit 1
fi
[ -n "$port" ] || port=$defaultport

if [ -n "${help}" ]; then
	cat <<EOF
This script will create a centos build server configuration in
/centos using yum, that can be used to build natively on a
Linux distribution other than CentoOS, for example: Ubuntu.

An ssh daemon running natively in the alternate environment will
be configured to accept connections on an alternate port, usually
23 since telnet is a deprecated protocol.

Your home directory in the chroot will be bound to the centos/
directory in your current home directory.

Usage: mkchroot.sh [OPTION]... --init [EXTRA PACKAGES...]
       mkchroot.sh [OPTION]... --stop

Options
     --root=PATH            install to PATH instead of /centos
     --init                 initialize a new chroot environment
     --start                start sshd, bind /proc
     --stop                 stop sshd, unbind /proc
     --revert               cleanup, revert system changes
 -p, --port=PORT            use port PORT instead of 23
 -x                         print debug output
 -h, --help                 show this help
EOF
	unset help
	exit 1
fi


if [ "root" != "$USER" ]; then
	echo $0 must be run as root, preferably with sudo.
	exit 1
fi

USER=$(logname)

if [ "root" = "$USER" ]; then
	echo Please enter the user that will be building in the chroot.
	read user
else
	user=$USER
fi

if [ ! -d /home/$user ]; then
	echo "/home/$user doesn't exist"
	exit 1
fi

home=/home/$user/centos

function mkchroot-stop () {
	chroot $root /etc/init.d/sshd stop
	umount $root/home/$user
	umount $root/tmp
	umount $root/dev/shm
	umount $root/dev/pts
	umount $root/proc
}

function mkchroot-start () {
	mount --bind /proc $root/proc
	mount --bind /dev/pts $root/dev/pts
	mount --bind /dev/shm $root/dev/shm
	mount --bind /tmp $root/tmp
	mount --bind $home $root/home/$user
	chroot $root /etc/init.d/sshd start
}

function yum () {
	$(which yum) -y -c $root/etc/yum.conf --installroot=$root "$@"
}

function mkchroot-init () {
	if ! which yum >/dev/null; then
		echo yum is not installed. On Ubuntu systems run \'sudo apt-get install yum\'
		exit 1
	fi

	if ! which rpm >/dev/null; then
		# If yum is installed, so should rpm be.
		echo rpm is not installed. On Ubuntu systems run \'sudo apt-get install rpm\'
		exit 1
	fi

	if [ -e $root ]; then
		cat <<-EOF
		Warning: $root already exists and will be overridden.

		Press enter to continue...
		EOF
		read

		mkchroot-stop
		rm -rf $root || exit $?
	fi

	set -e

	mkdir -p $root/etc $root/dev/shm $root/proc $root/sys $root/var/lib/rpm

	touch $root/etc/fstab

	mknod $root/dev/null c 1 3
	chmod 666 $root/dev/null
	cp -a /dev/urandom $root/dev/
	cp -a /dev/tty $root/dev/
	mkdir $root/dev/pts
	cp -a /dev/ptmx $root/dev/
	ln /etc/resolv.conf $root/etc/resolv.conf
	ln /etc/hosts $root/etc/hosts

	cp yum.conf $root/etc/yum.conf

	rpm --initdb --root $root
	#yum groupinstall "Core"
	yum install which bash rsync openssh-server $packages

	cat <<-"EOF" >> $root/root/.bash_profile
	if [ -f ~/.bashrc ]; then
	    . ~/.bashrc
	fi
	if [ -d ~/bin ] ; then
	    PATH=~/bin:"${PATH}"
	fi
	EOF

	cat <<-"EOF" >> $root/root/.bashrc
	PS1="[\u@chroot \W]\$ "
	EOF

	chroot $root useradd -u $(id -u $user) $user

	if [ ! -d $home ]; then
		mkdir $home
		cp $root/root/.bash* $home/
	fi

	if [ ! -d $home/.ssh ]; then
		mkdir $home/.ssh
		if [ -e /home/$user/.ssh/id_dsa.pub ]; then
			ssh-keygen -f "/home/$user/.ssh/known_hosts" -R [chroot]:23
			cat /home/$user/.ssh/id_dsa.pub >> $home/.ssh/authorized_keys
		elif [ -e /home/$user/.ssh/id_rsa.pub ]; then
			ssh-keygen -f "/home/$user/.ssh/known_hosts" -R [chroot]:23
			cat /home/$user/.ssh/id_rsa.pub >> $home/.ssh/authorized_keys
		else
			echo No id_dsa.pub or id_rsa.pub found is /home/$user/.ssh/
			chroot $root passwd $user
		fi
	fi
	chown $user.$user -R $home

	echo
	echo Setting ssh to listen on port $port
	sed -i -e "s/#Port 22/Port $port/" $root/etc/ssh/sshd_config

	if ! grep "chroot" /etc/hosts; then
	echo
	echo Adding chroot entry in /etc/hosts
	cat <<-EOF | tee -a /etc/hosts

	# Added by mkchroot.sh
	127.0.0.2	chroot
	EOF
	fi

	mkchroot-start

	cat <<-EOF

	Note: You must configure your ssh client to connect to the chroot ssh server
	on 127.0.0.2 port $port. To do so, add the following to ~/.ssh/config:

	Host chroot 127.0.0.2
	   Port $port 
	   ForwardAgent yes

	Then, configure your centos platform as such in your .rmakerc:

	centos=$user@chroot
	EOF
}

function mkchroot-revert () {
	cat <<-EOF
	Warning: $root will be removed.

	Press enter to continue...
	EOF
	read

	mkchroot-stop
	sed -i -e '/127.0.0.2.*chroot.*/d' -e '/.*mkchroot.*/d' /etc/hosts
	rm -rf $root
}

mkchroot-${cmd}
