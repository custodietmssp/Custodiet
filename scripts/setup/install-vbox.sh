#!/bin/sh -e

# install the most recent v-box and extension pack

# 130923 - dls - initial version


# =====================================
# variables

# vbox download site
vbox_site=download.virtualbox.org
vbox_download=${vbox_site}/virtualbox


# =====================================
# functions

download_checksums() {
	# always download a new version of the checksum file
	#+ so we can get the up-to-date version of the .deb filename to download
	rm --force SHA256SUMS
	wget ${url}/SHA256SUMS
}

download_vbox() {
	download_checksums

	# get the actual filename by grepping it in the SHA256SUMS file
	filename_deb=$( grep ~${id}~${codename}_${arch}.deb SHA256SUMS | \
		sed s:^.*\ .:: )
	echo "--filename_deb: ${filename_deb}"

	if [ -f "${filename_deb}" ] ; then
		echo "--> deb file already downloaded"
	else
		echo "--> downloading vbox deb; this will take a few moments"
		wget --progress=bar ${url}/${filename_deb}
	fi
	
	# run checksum
	echo "--> run checksum against download"
	grep ${filename_deb} SHA256SUMS | sha256sum -c
}

install_vbox() {
	echo "--updating pkg list - this could take a few moments"
	if aptitude -q=2 update ; then
		echo "--pkg list updated"
	else
		echo "---> \"aptitude update\" failed !!!"
		exit 1
	fi

	# first install dependency
	echo "--> installing dependencies for vbox"
	list_deps="
dkms
gcc
xmlstarlet
libsdl1.2debian
libgl1-mesa-glx
libqt4-network
libqt4-opengl
libqtcore4
libqtgui4
libvpx1
libxcursor1
libxinerama1
libxmu6
libxt6
"
	aptitude -y install ${list_deps}

	# install vbox
	echo "--> installing vbox .deb w/ dpkg"
	file_deb=$( ls ${vbox_deb_name_wc} )
	echo "--file_deb: ${file_deb}"
	dpkg -i ${file_deb} || true
	
	# this may be unnecessary, but sometimes it is not done at installation
	echo "--> compile/recompile vbox kernel modules"
	/etc/init.d/vboxdrv setup
}

download_extpack() {
	download_checksums

	# ext pack filename
	if [ -f ${filename_ext} ] ; then
		echo "-- extension pack already downloaded"
	else
		echo "--> downloading extension pack"
		wget ${url}/${filename_ext}
	fi

	# run checksum
	echo "--> run checksum against download"
	grep ${filename_ext} SHA256SUMS | sha256sum -c
}

install_extpack() {
	echo "--> installing extension pack"
	# the "--replace" switch must follow "install"
	VBoxManage extpack install --replace ${filename_ext}
}

# =====================================
# sanity checks

echo "-= $0 =-"

if [ $(id -u) = 0 ] ; then
	echo "--running as root: OK"
else
	echo "--> this script must be run as root !!!"
	exit 1
fi


# =====================================
# get version and downloads

# get the file containing version number of the most recent release
version_latest=$( wget -qO- ${vbox_download}/LATEST.TXT )
echo "--version_latest: ${version_latest}"

# dir contianing the files
url=http://${vbox_download}/${version_latest}

ver_major=$( echo ${version_latest} | cut -d . -f 1 )
echo "--ver_major: ${ver_major}"
ver_minor=$( echo ${version_latest} | cut -d . -f 2 )
echo "--ver_minor: ${ver_minor}"
ver_patch=$( echo ${version_latest} | cut -d . -f 3 )
echo "--ver_patch: ${ver_patch}"

id=$( lsb_release -s --id )
echo "--id: ${id}"
codename=$( lsb_release -s --codename )
echo "--codename: ${codename}"
arch=$( dpkg --print-architecture )
echo "--arch: ${arch}"

# =====================================
# install/upgrade vbox

# is vbox already installed
if which VBox ; then
	echo "--> vbox is already installed"
	# get the installed version
	##version_vbox=$(VBoxManage -v)
	##echo "version_vbox: ${version_vbox}"
	if VBoxManage -v | grep ${version_latest} ; then
		echo "--> vbox is already the latest version"
	else
		# NOT the latest version
		echo "--> installing a new version of vbox"
		download_vbox
		install_vbox
	fi
else
	download_vbox
	install_vbox
fi

# check that it is correctly installed
pkg_name=virtualbox-${ver_major}.${ver_minor}
if dpkg -l ${pkg_name} | grep ^iU ; then
	echo "---> there was a problem installing \"${pkg_name}\""
	echo "---> it is not configured correctly"
	echo "---> it may be missing dependencies"
	exit 1
else
	echo "--> ${pkg_name} is installed correctly"
fi


# =====================================
# install most recent version of extension pack

# check if extpack is installed
ext_packs=$( VBoxManage list extpacks | grep ^Version: | sed s/^.*:[[:space:]]*// )
echo "ext_packs: ${ext_packs}"

# this should be the filename of the most recent ext pack
filename_ext=Oracle_VM_VirtualBox_Extension_Pack-${ver_major}.${ver_minor}.${ver_patch}.vbox-extpack
echo "-- filename_ext: ${filename_ext}"

if [ "$( VBoxManage list extpacks )" = "Extension Packs: 0" ] ; then
	echo "--> extension pack is not installed"
	download_extpack
	install_extpack
elif [ "${ext_packs}" = ${version_latest} ] ; then
	echo "--> already have the most recent vbox extension pack"
else
	echo "--> extension pack is not the most recent"
	download_extpack
	install_extpack
fi


# =====================================
# fin
echo "- exiting -= $0 =-"
