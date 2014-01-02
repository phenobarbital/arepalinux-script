#!/bin/bash
# ================================================================================
# Arepa Linux: Build and optimize a Server-Based Debian GNU/Linux appliance
#
# Copyright © 2013 Jesús Lara Giménez (phenobarbital) <jesuslarag@gmail.com>
# Version: 0.1  
#
#    Developed by Jesus Lara (phenobarbital) <jesuslara@phenobarbital.info>
#    https://github.com/phenobarbital/arepalinux-1
#    
#    License: GNU GPL version 3  <http://gnu.org/licenses/gpl.html>.
#    This is free software: you are free to change and redistribute it.
#    There is NO WARRANTY, to the extent permitted by law.
# ================================================================================

# commands
CAT="$(which cat)"
GREP="$(which grep)"
AWK="$(which awk)"
SED="$(which sed)"
MOUNT="$(which mount)"
ECHO="$(which echo)"
SYSCTL="$(which sysctl)"
APT="$(which apt-get)"
APTITUDE="$(which aptitude)"
#

# get configuration
if [ -e /etc/arepalinux/arepalinux.conf ]; then
    . /etc/arepalinux/arepalinux.conf
else
    . ./etc/arepalinux.conf
fi

#
#  all common functions (for all templates)
#
if [ -e /usr/lib/arepalinux/libarepa.sh ]; then
    . /usr/lib/arepalinux/libarepa.sh
else
    . ./lib/libarepa.sh
fi


### main execution program ###


if [ "`id -u`" != "0" ]; then
$CAT << _MSG
  ---------------------------------------
  | Error !!                            |
  | Es necesario ser root para instalar |
  | Y configurar ArepaLinux $VERSION    |
  |                                     |
  | No se instalará nada!               |
  ---------------------------------------
_MSG
	exit 1
fi

main()
{
## auto-discover and autoinstall packages
DIST=`get_distribution`
SUITE=`get_suite`
NAME=`hostname --short`
# descubrir el dominio
get_domain
SERVERNAME=$NAME.$DOMAIN
ACCOUNT=`getent passwd | grep 1000 | cut -d':' -f1`
# deteccion de interface
firstdev
LAN_IPADDR="$(ip addr show $LAN_INTERFACE | awk "/^.*inet.*$LAN_INTERFACE\$/{print \$2}" | sed -n '1 s,/.*,,p')"
GATEWAY=$(get_gateway)
# network options
NETMASK=$(get_netmask $LAN_INTERFACE)
NETWORK=$(get_network $GATEWAY $NETMASK)
SUBNET=$(get_subnet $LAN_INTERFACE)
BROADCAST=$(get_broadcast $LAN_INTERFACE)
# FS OPTIONS
BOOTFS=$(cat /etc/fstab | grep boot | grep UUID | awk '{print $3}')
ROOTFS=$(cat /etc/fstab | grep " / " | grep UUID | awk '{print $3}')
hooksdir

## show summary
show_summary

	# TODO, ¿pedir confirmación para proceder luego del sumario?
	if [ "$VERBOSE" == 'true' ]; then
		read -p "Continue (y/n)?" WORK
		if [ "$WORK" != "y" ]; then
			exit 0
		fi
	fi
	# running debian hooks
	hooks="$HOOKSDIR"
	for f in $(find $hooks/* -maxdepth 1 -executable -type f ! -iname "*.md" ! -iname ".*" | sort --numeric-sort); do
		if [ "$WAIT" == 'true' ]; then 
			read -p "Continue (y/n)?" WORK
			if [ "$WORK" != "y" ]; then
				exit 0
			else
				. $f
			fi
		else
			. $f
		fi
	done
}

# = end = #
main

info "= All done. please restart system ="
exit 0
