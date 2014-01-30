#!/bin/sh -e

# install-cacti-client.sh

# 131024 - dls - initial version


# =====================================
# sanity checks

echo "-= $0 $@ =-"

# if we are not root, quit
if [ $( id -u ) -eq 0 ] ; then
	echo "running as root: OK"
else
	echo "this script must be run as root !!!"
	exit 1
fi


# =====================================
# install stuff

if dpkg -s snmp snmpd >/dev/null ; then
	echo "- snmp client pkgs already installed"
else
	echo "- installing snmp client pkgs"
	aptitude install snmp snmpd
fi


# =====================================
# fin
echo "- exiting -= $0 =-"
