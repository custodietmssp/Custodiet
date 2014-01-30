#!/bin/sh

# install-freenx-server.sh
# 130712 - dls	- initial version
# 121017 - dls - remove custom server key config at the end - it didn't work anyway

# install and configure freeNX server
#+ https://code.google.com/p/security-onion/wiki/FreeNX

# ===============================================

# ======================
# post a version number
echo "$0 -- version 131017"


# ======================
# variables

# url for nxsetup tarball
url_nxsetup=https://bugs.launchpad.net/freenx-server/+bug/576359/+attachment/1378450/+files/nxsetup.tar.gz
# FIXME - this url will change - find the correct way to get the setup script


# ======================
# sanity check

if [ $(id -u) = 0 ] ; then
	echo running as root, OK
else
	echo "This script must be run as root !!!"
	exit 1
fi


# ======================
# set some variables for this system
release=$(lsb_release -r | awk '{print $2}')
echo "release: ${release}"

codename=$(lsb_release -c | awk '{print $2}')
echo "codename: ${codename}"


# ======================
# add sources.list
ppa_slist=/etc/apt/sources.list.d/freenx-team-ppa-${codename}.list
if [ ! -e ${ppa_slist} ] ; then
	add-apt-repository --yes ppa:freenx-team
	# comment out deb-src line, we don't need sources pkg
	sed -i s/^deb-src/#deb-src/ ${ppa_slist}
fi


# ======================
# install freenx pkg
aptitude -q=2 update
aptitude -y install freenx


# ======================
# get the setup script, which dosen't come with the pkgs
# download
cd /tmp/
wget ${url_nxsetup}
# extract it
tar -xvf nxsetup.tar.gz
# move the setup script to the nxserver dir
mv nxsetup /usr/lib/nx/


# ======================
# run the setup script from the new location
/usr/lib/nx/nxsetup --install --setup-nomachine-key


# ======================
# create the X startup script
script=/opt/xstart.sh
touch ${script}
chmod +x ${script}
echo "#!/bin/sh" 												> ${script}
echo "export XDG_CONFIG_DIRS='/etc/xdg/xdg-xubuntu:/etc/xdg'"	>> ${script}

case ${release} in
#	10.04)	echo "exec /usr/share/xubuntu/session.sh"	>> ${script}	;;
	12.04)	echo "exec startxfce4"						>> ${script}	;;
#	13.04)	echo "exec startxfce4"						>> ${script}	;;
	*) 		echo "OS verson unknown; script unfinished !!!"				;;
esac


# ======================
# fin
