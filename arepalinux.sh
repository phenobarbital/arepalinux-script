#!/bin/bash
# ================================================================================
# Arepa Linux: Build and optimize a Server-Based Debian GNU/Linux appliance
#
# Copyright © 2013 Jesús Lara Giménez (phenobarbital) <jesuslarag@gmail.com>
# Version: 0.1  
#
#    Developed by Jesus Lara (phenobarbital) <jesuslara@phenobarbital.info>
#    https://github.com/phenobarbital/arepalinux-script
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

# get template
get_role() 
{
	if [ -z "$ROLENAME" ]; then
	    error "$(basename $0) role definition is missing, aborted"
		exit 1
	fi
	roledir
	if [ -f "$ROLEDIR/$ROLENAME" ]; then
			#verifico esta permisologia
			if [ ! -x "$ROLEDIR/$ROLENAME" ]; then
				error "error: role '$ROLEDIR/$ROLENAME' is not executable, try chmod o+x $ROLEDIR/$ROLENAME"
				return 1
			else
				debug "- using $ROLENAME as role"
				ROLE="$ROLEDIR/$ROLENAME"
			fi
	else
		error "$(basename $0) role $ROLENAME not exist, aborted"
		exit 1
	fi	
}

check_name()
{
	if [[ "${#1}" -gt 20 ]] || [[ "${#1}" -lt 2 ]]; then
		usage_err "hostaname '$1' is an invalid name"
	fi
}

check_domain()
{
	if [[ "${#1}" -gt 254 ]] || [[ "${#1}" -lt 2 ]]; then
		usage_err "domain name '$1' is an invalid domain name"
	fi
	if [ -z echo "${#1}" | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)' ]; then
		usage_err "domain name '$1' is an invalid domain name"
	fi
}

check_mode()
{
	if [[ "$1" = "server" || "$1" = "workstation" || "$1" = "desktop" ]]; then
		return 0
	else
		usage_err "option '$1' invalid server mode"
	fi
}

### main execution program ###

NAME=''
SIZE=''
IP=''
IFACE=''
LAN_INTERFACE=''
DIST=''
TEMPLATE=''
HOSTNAME=''
SERVERNAME=''
STEP=''
MODE='desktop'
DEBUG='false'

usage() {
	echo "Usage: $(basename $0) [-m|--mode=<desktop|server|workstation>] [-n|--hostname=<hostname>] [-D|--domain=DOMAIN]
        [-r|--role=<role-name>] [-l|--lan=<lan interface>] [--packages=<comma-separated package list>] [--debug] [-h|--help]"  
    return 1
}

help() {
	usage
cat <<EOF

This script is a helper to install a Debian GNU/Linux Server-Oriented

Automate, Secure and easily install a Debian Enterprise-ready Server/Workstation

Options:
  -n, --hostname             specify the name of the debian server
  -r, --role                 role-based script for running in server after installation
  -D, --domain               define Domain Name
  -m, --mode                 mode for system installation, default mode: desktop
  -l, --lan                  define LAN Interface (ej: eth0)
  --packages                 Extra comma-separated list of packages
  --debug                    Enable debugging information
  Help options:
      --help     give this help list
      --usage	 Display brief usage message
      --version  print program version
EOF
	echo ''
	get_version
	exit 1
}


if [ "$(id -u)" != "0" ]; then
   error "$(basename $0): must be run as root" >&2
   exit 1
fi

# processing arguments
ARGS=`getopt -n$0 -u -a -o r:n:m:D:l:h --longoptions packages:,debug,usage,verbose,version,help,mode::,lan::,step::,domain::,role::,hostname:: -- "$@"`
eval set -- "$ARGS"

while [ $# -gt 0 ]; do
	case "$1" in
        -m|--mode)
			optarg_check $1 "$2"
            check_mode "$2"
            MODE=$2
            shift
            ;;	
        -n|--hostname)
			optarg_check $1 "$2"
            check_name "$2"
            NAME=$2
            shift
            ;;
        -r|--role)
			optarg_check $1 "$2"
            ROLENAME=$2
            shift
            ;;
        -D|--domain)
			optarg_check $1 "$2"
            check_domain $2
            DOMAIN=$2
            shift
            ;;
        -l|--lan)
			optarg_check $1 "$2"
            LAN_INTERFACE=$2
            shift
            ;;
        --step)
			optarg_check $1 "$2"
            STEP=$2
            shift
            ;;            
        --packages)
			optarg_check $1 "$2"
			PACKAGES="$2"
			shift
			;;           
        --debug)
            DEBUG='true'
            ;;
        --verbose)
            VERBOSE='true'
            ;;     
        --version)
			get_version
			exit 0;;
        -h|--help)
            help
            exit 1
            ;;
        --)
            break;;
        -?)
            usage_err "unknown option '$1'"
            exit 1
            ;;
        *)
            usage
            exit 1
            ;;
	esac
    shift
done

main()
{
## discover Debian suite (ex: wheezy)
SUITE=`cat /etc/apt/sources.list | grep -F "deb http:" | head -n1 |  awk '{ print $3}' | cut -d '/' -f1`
DIST="Debian"

# DIST=`get_distribution`
# SUITE=`get_suite`

	# si no pasamos ningun parametro
	if [ $# = 0 ]; then
		# descubrir el nombre del equipo
		get_hostname
		# descubrir el dominio
		get_domain
		# deteccion de interface
		firstdev
	fi
SERVERNAME=$NAME.$DOMAIN
# get first account
ACCOUNT=`getent passwd | grep 1000 | cut -d':' -f1`
hooksdir

# FS OPTIONS
BOOTFS=$(cat /etc/fstab | grep boot | grep UUID | awk '{print $3}')
ROOTFS=$(cat /etc/fstab | grep " / " | grep UUID | awk '{print $3}')


LAN_IPADDR="$(ip addr show $LAN_INTERFACE | awk "/^.*inet.*$LAN_INTERFACE\$/{print \$2}" | sed -n '1 s,/.*,,p')"
if [ -z "$LAN_INTERFACE" ]; then
	error "LAN Interface its not defined"
	exit 1
fi
if [ -z "$LAN_IPADDR" ]; then
	error "LAN Interface $LAN_INTERFACE not configured, please assign a IP Address"
	exit 1
fi
GATEWAY=$(get_gateway)
# network options
NETMASK=$(get_netmask $LAN_INTERFACE)
NETWORK=$(get_network $GATEWAY $NETMASK)
SUBNET=$(get_subnet $LAN_INTERFACE)
BROADCAST=$(get_broadcast $LAN_INTERFACE)

if [ ! -z "$STEP" ]; then
	debug "Resuming Arepa Linux installation"
	step=$(find $HOOKSDIR/* -maxdepth 1 -executable -type f -name "$STEP-*")
	if [ -n "$step" ]; then
		read -p "Continue with $step (y/n)?" WORK
		if [ "$WORK" != "y" ]; then
			exit 0
		else
			. $step
		fi
	fi
	exit 0
fi

debug "= Arepa Linux Installation Summary = "
## show summary
show_summary

	# TODO, ¿pedir confirmación para proceder luego del sumario?
	if [ "$VERBOSE" == 'true' ]; then
		read -p "Continue with installation (y/n)?" WORK
		if [ "$WORK" != "y" ]; then
			exit 0
		fi
	fi
	for f in $(find $HOOKSDIR/* -maxdepth 1 -executable -type f ! -iname "*.md" ! -iname ".*" | sort --numeric-sort); do
		if [ "$DEBUG" == 'true' ]; then 
			read -p "Continue with $f (y/n)?" WORK
			if [ "$WORK" != "y" ]; then
				exit 0
			else
				. $f
			fi
		else
			. $f
		fi
	done
	
	# executing a role
	if [ ! -z "$ROLENAME" ]; then
		get_role
		. $ROLE
		run
		if [ "$?" -ne "0" ]; then
			error "failed to execute role $ROLENAME"
		fi
	fi
	
	# installing packages list
	if [ ! -z "$PACKAGES" ]; then
		install_package $(echo $PACKAGES | tr ',' ' ')
	fi
	
	# installation summary:
	install_summary
}

# = end = #
main

warning "Reboot needed"
info "= All done. please restart system to apply changes ="
exit 0
