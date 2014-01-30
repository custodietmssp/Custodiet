#!/bin/bash -e

# create-vbox-account.sh - install/create an account for headless VirtualBox VMs

# 131002 - dls - initial version


# =====================================
# variables

vm_account=vbox


# =====================================
# sanity check

echo -= $0 $@ =-

if [ $( id -u ) -eq 0 ] ; then
	echo "- running as root; OK"
else
	echo "this script must be run as root !!!"
	exit 1
fi


# =====================================
# main

echo "- create the vbox user account & home directory"
if id ${vm_account} ; then
	echo "-  vm_account \"${vm_account}\" already exists"
else
	adduser \
		--ingroup vboxusers \
		--disabled-password \
		--gecos "account to run virtual machines" \
		${vm_account}
fi


# =====================================
# fin
