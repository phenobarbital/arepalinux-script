#!/bin/bash
##
#  /usr/lib/arepalinux/libarepa.sh
#
#  Common shell functions which may be used by any arepalinux template
#
##

VERSION='0.1'


## functions 

export NORMAL='\033[0m'
export RED='\033[1;31m'
export GREEN='\033[1;32m'
export YELLOW='\033[1;33m'
export WHITE='\033[1;37m'
export BLUE='\033[1;34m'

logMessage () {
  scriptname=$(basename $0)
  if [ -f "$LOGFILE" ]; then
	echo "`date +"%D %T"` $scriptname : $@" >> $LOGFILE
  fi
}

get_version() 
{
	echo "ArepaLinux Version $VERSION";
}

# basic functions
#

#  If we're running verbosely show a message, otherwise swallow it.
#
message()
{
    message="$*"
    echo -e $message >&2;
    logMessage $message
}

info()
{
	message="$*"
    if [ "$VERBOSE" == "true" ]; then
		printf "$GREEN"
		printf "%s\n"  "$message" >&2;
		tput sgr0 # Reset to normal.
		echo -e `printf "$NORMAL"`
    fi
    logMessage $message
}

warning()
{
	message="$*"
    if [ "$VERBOSE" == "true" ]; then
		printf "$YELLOW"
		printf "%s\n"  "$message" >&2;
		tput sgr0 # Reset to normal.
		printf "$NORMAL"
    fi
    logMessage "WARN: $message"
}

debug()
{
	message="$*"
	if [ "$VERBOSE" == "true" ]; then
    # if [ ! -z "$VERBOSE" ] || [ "$VERBOSE" == "true" ]; then
		printf "$BLUE"
		printf "%s\n"  "$message" >&2;
		tput sgr0 # Reset to normal.
		printf "$NORMAL"
    fi
    logMessage "DEBUG: $message"
}

error()
{
	message="$*"
	scriptname=$(basename $0)
	printf "$RED"
	printf "%s\n"  "$scriptname $message" >&2;
	tput sgr0 # Reset to normal.
	printf "$NORMAL"
	logMessage "ERROR:  $message"
	return 1
}

usage_err()
{
	error "$*"
	exit 1
}

optarg_check() 
{
    if [ -z "$2" ]; then
        usage_err "option '$1' requires an argument"
    fi
}

hooksdir()
{
		if [ -d "/usr/share/arepalinux/hooks.d" ]; then
			HOOKSDIR="/usr/share/arepalinux/hooks.d"
		else
			HOOKSDIR="./hooks.d"
		fi
}

roledir()
{
		if [ -d "/usr/share/arepalinux/role.d" ]; then
			ROLEDIR="/usr/share/arepalinux/role.d"
		else
			ROLEDIR="./role.d"
		fi
}

show_summary()
{

SUMMARY=$(cat << _MSG
 ---------- [ Summary options for Installation ] ---------------

  Mode : .......................... $MODE  
  Name : .......................... $NAME
  ServerName : .................... $SERVERNAME
  RootFS : ........................ $ROOTFS
  BootFS : ........................ $BOOTFS
  Distribution : .................. $DIST
  Suite : ......................... $SUITE
  Domain : ........................ $DOMAIN
  SSH Port : ...................... $SSH_PORT
 ---------------------------------------------------------------
_MSG
)

echo "$SUMMARY"
}


install_summary()
{

sshport=$(cat /etc/ssh/sshd_config | grep Port | cut -d ' ' -f2)

SUMMARY=$(cat << _MSG
 ---------- [ Status of Installation ] ---------------

  Mode : .......................... $MODE  
  Name : .......................... $NAME
  ServerName : .................... $SERVERNAME
  SSH Port : ...................... $sshport
  IP : ............................ $LAN_IPADDR
   
 ---------------------------------------------------------------
_MSG
)

echo "$SUMMARY"
}

### domain info

define_domain()
{
	echo -n 'Please define a Domain name [ex: example.com]: '
	read _DOMAIN_
	if [ -z "$_DOMAIN_" ]; then
		message "error: Domain not defined"
		return 1
	else
		DOMAIN=$_DOMAIN_
	fi
}

get_hostname()
{
	if [ -z "$NAME" ]; then
		NAME=`hostname --short`
	fi
}

get_domain() 
{
	if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "auto" ]; then
		# auto-configure domain:
		_DOMAIN_=`hostname -d`
		if [ -z "$_DOMAIN_" ]; then
			define_domain
		else
			DOMAIN=$_DOMAIN_
		fi
	fi
}

### Debian functions

# return host distribution based on lsb-release
get_distribution() 
{
	if [ -z $(which lsb_release) ]; then
		echo "lxc-tools error: lsb-release is required"
		exit 1
	fi
	lsb_release -s -i
}

# get codename (ex: wheezy)
get_suite() 
{
	if [ -z $(which lsb_release) ]; then
		echo "lxc-tools error: lsb-release is required"
		exit 1
	fi
	lsb_release -s -c
}

# install package with no prompt and default options
install_package()
{
	message "installing Debian package $@"
	#
	# Install the packages
	#
	DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --option Dpkg::Options::="--force-overwrite" --option Dpkg::Options::="--force-confold" --yes --force-yes install "$@"
}

is_installed()
{
	pkg="$@"
	if [ -z "$pkg" ]; then
		echo `dpkg -l | grep -i $pkg | awk '{ print $2}'}`
	fi
	return 0
}
### network functions

ifdev() {
IF=(`cat /proc/net/dev | grep ':' | cut -d ':' -f 1 | tr '\n' ' '`)
}

firstdev() {
	if [ -z "$LAN_INTERFACE" ]; then
		ifdev
		LAN_INTERFACE=${IF[1]}
	fi
}

# get ip from interface
get_ip() {
	# get ip info
	IP=`ip addr show $1 | grep "[\t]*inet " | head -n1 | awk '{print $2}' | cut -d'/' -f1`
	if [ -z "$IP" ]; then
		echo ''
	else
		echo $IP
	fi
}

# get default gateway from LAN
get_gateway() {
	ip route | grep "default via" | awk '{print $3}'
}

# get netmask from IP
get_netmask() {
	ifconfig $1 | sed -rn '2s/ .*:(.*)$/\1/p'
}

# get network from ip and netmask
get_network() {
	IFS=. read -r i1 i2 i3 i4 <<< "$1"
	IFS=. read -r m1 m2 m3 m4 <<< "$2"
	printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$(($i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

# get broadcast from interface
get_broadcast() {
	# get ip info
	ip addr show $1 | grep "[\t]*inet " | head -n1 | egrep -o 'brd (.*) scope' | awk '{print $2}'
}

# get subnet octect
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
}

get_subnet() {
	MASK=`get_netmask $1`
	echo $(mask2cidr $MASK)
}
