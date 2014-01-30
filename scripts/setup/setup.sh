#!/bin/bash -e

# setup.sh - install and configure all the necessary stuff

# 130917 - dls - initial version
# 131213 - dls - fixes


# =====================================
# variables

# list of groups for the admin accounts
admin_groups="
adm
cdrom
floppy
tape
sudo
audio
dip
video
plugdev
fuse
scanner
lpadmin
netdev
sambashare
"

# this url might change with new versions of freenx
url_nxsetup_script=https://bugs.launchpad.net/freenx-server/+bug/576359/+attachment/1378450/+files/nxsetup.tar.gz

# local customizations - mostly used for development
local_setup_script=./setup-local.sh

# sosetup & sosetup-network scripts
sosetup_script=./sosetup
sosetup_network_script=./sosetup-network

# FreeNX server installation script
freenx_install_script=./install-freenx-server.sh

# virtualbox installation script
vbox_install_script=./install-vbox.sh

# account creation script
vbox_account_script=./create-vbox-account.sh

# VM creation script
vbox_vm_script=./create-vm.sh

# VM data file
vbox_vm_data=./srv00.data

# Cacti client install script
cacti_install_script=./install-cacti-client.sh


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


# ==========================================
# functions

# update pkg catalog 
# but not if it has already been run in the last hour
apt_update() {
	if [ $(( $(date +%s) - $(stat -c %Z /var/cache/apt/pkgcache.bin) )) -gt $(( 24 * 60 )) ] ; then
		echo "- running pkg catalog update"
		aptitude -q=2 update
	else
		echo "- pkg catalog is up-to-date within an hour"
	fi
}

set_pw_hash() {

	# set a pw hash
	data=$(grep ^gr${a}: /etc/shadow)
	echo "data: ${data}"
	
	current_hash=$( grep ^gr${a}: /etc/shadow | cut -d : -f 2 )
	echo "current_hash: ${current_hash}"

	# don't write a hash if there is already one in shadow for this account
	if [ -z ${current_hash} ] ; then

		echo - inserting new hash
		
		# get hash from data file
		new_hash=$( eval echo \${hash_$a} )
		echo "- new_hash: ${new_hash}"

		# replace any "$" in the hash
		new_1_hash=$( echo ${new_hash}   | sed -E "s+[$]+QQQQQ+g" )
		# replace any "/" in the hash
		new_2_hash=$( echo ${new_1_hash} | sed -E "s+[/]+SLASH+g" )
		echo "- new_2_hash: ${new_2_hash}"

		# put in the 2nd version of the hash
		sed -i -e "/gr${a}/s/::/:${new_2_hash}:/" /etc/shadow
		
		# now replace markers with original chars
		sed -i -e "/^gr${a}/s/QQQQQ/\$/g" /etc/shadow
		sed -i -e "/^gr${a}/s/SLASH/\//g" /etc/shadow
		# show this change
		grep ^gr${a} /etc/shadow
	else
		echo - account: "${a}" already has a hash
	fi
}






# ==========================================
# initalize - get data on target system

echo "- PWD: ${PWD}"

dist_id=$( lsb_release -i | awk '{ print $3}' | tr [:upper:] [:lower:] )
echo "dist_id: ${dist_id}"
export dist_id

release=$( lsb_release -r | awk '{ print $2}' )
echo "release: ${release}"
export release

codename=$( lsb_release -c | awk '{ print $2}' )
echo "codename: ${codename}"
export codename

# read in data file
ls -lha setup.data
if [ -e setup.data ] ; then
	echo - sourcing setup.data file
	. setup.data
else
	echo "data file \"setup.data\" not found !!!"
	exit 1
fi


# =====================================
# custom config -- run the custom script if it exists

# if we have an executable local setup script, run it
if [ -x ${local_setup_script} ] ; then
	${local_setup_script}
fi


# =====================================
# upgrade out-of-date pkgs

echo "- running pkg upgrade"
apt_update
aptitude -y safe-upgrade


# =====================================
# install some extra utilities

echo "- installing extra utilities"
aptitude -y install ${list_utils}


# =====================================
# run sosetup & sosetup-network
if [ -x ${sosetup_script} ] ; then
	${sosetup_script} -d -s ${sosetup_script}.data -n ${sosetup_network_script}.data
fi


# =====================================
# create admin accounts
for a in ${list_accounts} ; do

	# add accounts, but don't fail if account already exists
	adduser --disabled-password --gecos "admin user" gr$a || true

	# add this account to the admin groups
	for g in ${admin_groups} ; do
		adduser gr$a $g
	done

	# add an ssh public key
	mkdir -p /home/gr$a/.ssh/
	pub_key=$(find ./ -name ${a}_id_?sa.pub)
	echo "- pub_key: ${pub_key}"
	if [ -z ${pub_key} ] ; then
		echo "can't find public key for \"${a}\" !!!"
		exit 1
	fi
	if ssh-keygen -l -f ${pub_key} | grep ^2048 ; then
		echo - key is 2048 length
		cp ${pub_key}	/home/gr$a/.ssh/authorized_keys2
		chown gr${a}:	/home/gr$a/.ssh/authorized_keys2
		chmod 400		/home/gr$a/.ssh/authorized_keys2
	fi

	set_pw_hash
done


# ==========================================
# FreeNX server

if [ -x ${freenx_install_script} ] ; then
	echo "- installing FreeNX server"
	${freenx_install_script}
else
	echo "\"${freenx_install_script}\" script not found !!!"
	exit 1
fi


# ==========================================
# install VBox

if [ -x ${vbox_install_script} ] ; then
	echo "- running ${vbox_install_script}"
	${vbox_install_script}
else
	echo "\"${vbox_install_script}\" script not found !!!"
	exit 1
fi


# =====================================
# create "vbox" account

# create the account for the vm
if [ -x ${vbox_account_script} ] ; then
	echo "- creating VM"
	${vbox_account_script}
else
	echo "\"${vbox_account_script}\" script not found !!!"
	exit 1
fi

#####################################################
# skip vbox virtual machine creation
if false ; then


# =====================================
# create VM(s)

# copy 2 scripts to ~vbox/
if [ -x ${vbox_vm_script} -a -f ${vbox_vm_data} ] ; then
	echo "- copying VM creation script & data to ~vbox/"
	cp \
		${vbox_vm_script} \
		${vbox_vm_data} \
		 ~vbox/
else
	echo "\"${vbox_vm_script}\" script or \"${vbox_vm_data}\" not found !!!"
	exit 1
fi

# get the vdi file
source ${vbox_vm_data}
echo "vm_hdd_image: ${vm_hdd_image}"

	# copy the image file
if [ -f ~vbox/${vm_hdd_image} ] ; then
	echo "- ${vm_hdd_image} already copied"
else
	echo "- copying \"${vm_hdd_image}\" to ~vbox/"
	rsync ./${vm_hdd_image} ~vbox/
fi

# change owner:group to vbox
chown vbox: ~vbox/${vm_hdd_image}

# run the script as the user "vbox"
echo "creating VM as user ~vbox"
su --login -c "${vbox_vm_script} ${vbox_vm_data}" vbox


# =====================================
# autolaunch VM

# fix up the startup script with values for this v-host
sed -i \
	-e /^[[:space:]]*VM_LONG_NAME/s/=.*$/=${vm_name}/ \
	-e /^[[:space:]]*VM_OWNER/s/=.*$/=vbox/ \
	-e /^[[:space:]]*VM_HOSTNAME/s/=.*$/=${vm_name}/ \
	 vbox-NAME
grep "^[[:space:]]*VM_LONG_NAME"	vbox-NAME
grep "^[[:space:]]*VM_OWNER"		vbox-NAME
grep "^[[:space:]]*VM_HOSTNAME"		vbox-NAME

# move the startup script to init.d and rename it
mv vbox-NAME /etc/init.d/vbox-${vm_name}

# configure to launch at OS startup
update-rc.d vbox-${vm_name} defaults 90

# create shutdown policy
file_defaults=/etc/default/virtualbox
if [ -f ${file_defaults} ] ; then
	echo "- vbox service shutdown defaults file already exists"
else
	echo "- creating \"${file_defaults}\""
	# space-delimited list of users who might have runnings VMs
	# if any are found, suspend them to disk
	echo "SHUTDOWN_USERS=vbox"	>${file_defaults}
	echo "SHUTDOWN=savestate"	>>${file_defaults}
fi


#################################################
fi
# end of vbox VM skip section


# =====================================
# install cacti agent

if [ -x ${cacti_install_script} ] ; then
	echo "- running ${cacti_install_script}"
	${cacti_install_script}
else
	echo "\"${cacti_install_script}\" script not found !!!"
	exit 1
fi


# =====================================
# FIXME - remove custom-0 settings

# put sources.list back
# remove dlmc.list


# =====================================
# FIXME
# http://www.howtoforge.com/ssh-best-practices


# =====================================
# fin
