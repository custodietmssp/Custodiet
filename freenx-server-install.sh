#!/bin/sh

# install and configure freeNX server
#+ https://code.google.com/p/security-onion/wiki/FreeNX

# 130712 - dls	- initial version

# =====================================

# ----------------------
# sanity check

if [ $(id -u) = 0 ] ; then
	echo running as root, OK
else
	echo "This script must be run as root !!!"
	exit 1
fi

# ----------------------
# add sources.list
if [ ! -e /etc/apt/sources.list.d/freenx-team-ppa-precise.list ] ; then
	add-apt-repository --yes ppa:freenx-team
	aptitude update
fi

# ----------------------
# install freenx pkg
aptitude -y install freenx

# ----------------------
# download the setup script
cd /tmp/
wget https://bugs.launchpad.net/freenx-server/+bug/576359/+attachment/1378450/+files/nxsetup.tar.gz

# ----------------------
# extract it
tar -xvf nxsetup.tar.gz

# ----------------------
# move the setup script to the correction location
mv nxsetup /usr/lib/nx/

# ----------------------
# run setup
sudo /usr/lib/nx/nxsetup --install

# ----------------------
# create the startup script
script=/opt/xstart.sh
touch ${script}
chmod +x ${script}
echo "#!/bin/sh" 												> ${script}
echo "export XDG_CONFIG_DIRS='/etc/xdg/xdg-xubuntu:/etc/xdg'"	>> ${script}

release=$(lsb_release -r | awk '{print $2}')
echo "release: ${release}"
case ${release} in
#	10.04)	echo "exec /usr/share/xubuntu/session.sh"	>> ${script}	;;
	12.04)	echo "exec startxfce4"						>> ${script}	;;
#	13.04)	echo "exec startxfce4"						>> ${script}	;;
	*) 		echo "OS verson unknown; script unfinished !!!"				;;
esac

# ----------------------
# cat the key to be used in the client setup
echo "copy this key and past it into the client"
cat /var/lib/nxserver/home/.ssh/client.id_dsa.key

