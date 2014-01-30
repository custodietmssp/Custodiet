#!/bin/bash -e

# create-vm.sh -- create/install a v-box virtual machine

# https://www.virtualbox.org/manual/
# http://xmodulo.com/2013/05/how-to-create-and-start-virtualbox-vm-without-gui.html
# http://www.perkin.org.uk/posts/create-virtualbox-vm-from-the-command-line.html

# 130923 - dls - initial version
# 131002 - dls - run as normal account, not root


# =========================================================
# sanity checks

echo -= $0 $@ =-

# check that we are NOT running as root
if [ $( id -u ) -eq 0 ] ; then
	echo "this script must NOT be run as root"
	echo "run it as a regular user"
	echo "or as the \"vbox\" user"
	exit 1
else
	echo "- script running as ${USER}; OK"
fi

# make sure we have the VM data file
if [ $# -eq 0 ] ; then
	echo "VM data file not on commandline !!!"
	exit 1
fi

# make sure we have xmlstarlet installed
if [ -z "$( which xmlstarlet )" ] ; then
	echo "- xmlstarlet is NOT installed and is required for this script"
	echo "-  run the following as root:"
	echo " apt-get install xmlstarlet"
	exit 1
else
	echo "- xmlstarlet is installed"
fi


# =========================================================
# read data file

vm_name=
vm_ostype=
vm_memory=
vm_cpus=
vm_iso=
vm_hdd_image=
vm_hd_size=

# assume that the first cl parameter is the VM data file
source $1

# vm_name
if [ -z "${vm_name}" ] ; then
	echo "vm_name: not set in $1"
	echo "this is mandetory !!!"
	exit 1
fi
echo "vm_name: ${vm_name}"

# vm_ostype
if [ -z "${vm_ostype}" ] ; then
	echo "vm_ostype: not set using default - Ubuntu_64"
	vm_ostype=Ubuntu_64
fi
echo "vm_ostype: ${vm_ostype}"

# vm_memory
if [ -z "${vm_memory}" ] ; then
	echo "vm_memory not set; using default 512"
	vm_memory=512
fi
echo "vm_memory: ${vm_memory}"

# vm_cpus
if [ -z ${vm_cpus} ] ; then
	echo "vm_cpus; not set; using default 1"
	vm_cpus=1
fi
echo "vm_cpus: ${vm_cpus}"

# vm_iso
echo "vm_iso: ${vm_iso}"

# vm_hdd_image
echo "vm_hdd_image: ${vm_hdd_image}"

# vm_hd_size
#+ ignore this if "vm_hdd_image" is supplied
if [ -n "${vm_hdd_image}" ] ; then
	# ignore if image is supplied
	echo "!!! ignoring vm_hdd_size=${vm_hdd_size} because image has been specified !!!"
	vm_hd_size=
fi
echo "vm_hd_size: ${vm_hd_size}"


# =========================================================
# set the VM machine dir

# ----------------------
# if this is the first VM in this account
#+ use "~/vms/" instead of "~/VirtualBox VMs/"
#+ dir name w/o a space makes the following scripting easier
if [ ! -d ${HOME}/.VirtualBox/ ] ; then
	# VBoxManage won't automatically create a settings folder
	mkdir .VirtualBox/
	# this is the 1st vm for this account
	echo "- put virtual machines in ~/vms/ dir"
	VBoxManage setproperty machinefolder ${HOME}/vms
fi

# get the current value in defaultMachineFolder
def_mach_dir="$( \
	xmlstarlet el -v ${HOME}/.VirtualBox/VirtualBox.xml | \
	grep SystemProperties | \
	sed s/^.*defaultMachineFolder=// | \
	cut -d "'" -f 2 \
	)"
echo "def_mach_dir: ${def_mach_dir}"

vm_dir_full="${def_mach_dir}/${vm_name}"

# variable pointing to dir containing this new VM
echo "- vm_dir_full: ${vm_dir_full}"


# =========================================================
# check if the VM already exists and is running
if VBoxManage list vms | grep ${vm_name} ; then
	echo "- the VM \"${vm_name}\" exists and is running !!"
	exit 0
else
	echo "- the VM \"${vm_name}\" is NOT running; skipping VM creation"
fi


# =========================================================
# create the new VM and what hw it has available

echo "- create and register the VM \"${vm_dir_full}/${vm_name}.vbox\""
if [ -f "${vm_dir_full}/${vm_name}.vbox" ] ; then
	echo "-  VM \"${vm_name}\" already exists"
else
	VBoxManage createvm --name "${vm_name}" --register
	# FIXME memory
fi

# this OS type seems to be optional
echo "- set the VM os type"
VBoxManage modifyvm "${vm_name}" --ostype ${vm_ostype}

# standard is UTC BIOS time for UNIX/Linux
echo "- set the VM BIOS to use UTC"
VBoxManage modifyvm "${vm_name}" --rtcuseutc on


# =========================================================
# memory

# default memory is: 128MB
echo "- set the VM memmory"
VBoxManage modifyvm "${vm_name}" --memory ${vm_memory}

# pagefusion can potentially save memory
echo "- allow VMs to share identical memory pages"
VBoxManage modifyvm "${vm_name}" --pagefusion on

# performance increase on intel
echo "- enable largepages performance increase on intel"
VBoxManage modifyvm "${vm_name}" --largepages on

# prevent the warning message about not enough vram to switch to full screen
#+ default is 8, 9 is minimum to avoid warning
echo "- set video memory to 10 Mb"
VBoxManage modifyvm "${vm_name}" --vram 10


# =========================================================
# CPU stuff
echo "- set CPU to ${vm_cpus}"
VBoxManage modifyvm "${vm_name}" --cpus ${vm_cpus}

# enable CPU hotplugging in case we want it later
#echo "-- enable CPU hotplugging"
#VBoxManage modifyvm "${vm_name}" --cpuhotplug on


# =========================================================
# networking
echo "-- set networking"
VBoxManage modifyvm "${vm_name}" --nic1 nat


# =========================================================
# media

echo "- setup a storage controllers"

echo "- create IDE controller"
name_cntrl="IDE_Controller"
if VBoxManage showvminfo "${vm_name}" | \
	grep -i "Storage Controller" | \
	grep "${name_cntrl}"
then
	echo "-  storage controller \"${name_cntrl}\" already setup"
else
	VBoxManage storagectl "${vm_name}" \
		--name "${name_cntrl}" \
		--add ide
#		--controller IntelAHCI
fi

echo "- mount ISO"
if [ -n "${vm_iso}" ] ; then
	echo "-  mounting ${vm_iso}"
	VBoxManage storageattach "${vm_name}" \
		--storagectl "IDE_Controller" \
		--port 0 \
		--device 0 \
		--type dvddrive \
		--medium "${HOME}/${vm_iso}"
else
	echo "-  no ISO specified"
fi

echo "- create SATA controller"
name_cntrl="SATA_Controller"
# check if we already have one
if VBoxManage showvminfo "${vm_name}" | \
	grep -i "Storage Controller" | \
	grep "${name_cntrl}"
then
	echo "-  storage controller \"${name_cntrl}\" already setup"
else
	VBoxManage storagectl "${vm_name}" \
		--name "${name_cntrl}" \
		--add sata
fi

# attach a preconfigured hdd image, or create and attach a VDI hdd

echo "- virtual hdd storage"
if [ -n "${vm_hd_size}" ] ; then
echo got here 1

	# create and use a VDI hdd
	if [ -f "${vm_dir_full}/${vm_name}.vdi" ] ; then
		echo "-  VDI hdd already created"
	else
echo got here 2
echo ${vm_dir_full}/${vm_name}
		echo "-  creating VDI hdd"
		VBoxManage createhd	\
			--filename "${vm_dir_full}/${vm_name}" \
			--size ${vm_hd_size}
	fi
	hdd="${vm_dir_full}/${vm_name}.vdi"
else
	echo "-  using preconfigured image instead"
	# use preconfigured image
	# move it into place in the VM data dir
	mv "${vm_hdd_image}" "${vm_dir_full}"
	hdd="${vm_dir_full}/${vm_hdd_image}"
fi

echo "- attach storage"
VBoxManage storageattach "${vm_name}" \
	--storagectl "${name_cntrl}" \
	--port 0 \
	--type hdd \
	--medium "${hdd}"

# boot order
echo "- set the VM boot order"
VBoxManage modifyvm "${vm_name}" --boot1 dvd
VBoxManage modifyvm "${vm_name}" --boot2 disk
VBoxManage modifyvm "${vm_name}" --boot3 none
VBoxManage modifyvm "${vm_name}" --boot4 none


# =========================================================
# print a summary of this VM

echo
#echo "info on \"${vm_name}\""
#VBoxManage showvminfo "${vm_name}" > ${vm_name}.info


# =====================================
# fin
