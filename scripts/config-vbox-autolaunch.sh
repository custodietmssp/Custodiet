#!/bin/sh -e

# config-vbox-autolaunch.sh -- configure vbox for autostarting VMs at system boot

# this comes from several sites:
# https://www.virtualbox.org/manual/ch09.html#autostart
# http://www.glump.net/howto/virtualization/how-to-setup-virtualbox-as-a-service-in-linux
# https://github.com/bkidwell/vbox-service-template/blob/master/vbox-service-template

# 130903 - dls - initial version

# ===============================================
# variables

# group containing users allowed to configure autostart
group_autostart=vboxautostartusers

# accounts which will be members of ${group_autostart}
accounts_autostart="david"

# autostart database directory
dir_vbox_autostart=/var/lib/vbox/autostart_db

# defualts file - vbox startup script will source this file on boot
file_defualt_config=/etc/default/virtualbox

# 
file_autostart_config=/etc/vbox/autostart.cfg


# ===============================================
# main

# -----------------

# create the group and make sure it doesn't fail if the group already exists
addgroup --system ${group_autostart} || true

# put the accounts in the group
for u in ${accounts_autostart} ; do
	adduser  ${u}  ${group_autostart}
done

# -----------------

# create the autostart database directory
mkdir -p ${dir_vbox_autostart}
# give write permissions to autostart group
# and set the sticky bit
chgrp  ${group_autostart}  ${dir_vbox_autostart}
chmod  1770  ${dir_vbox_autostart}

# -----------------

# create default config for vbox
cat > ${file_defualt_config} <<EOF
# an absolute path to the autostart database directory
VBOXAUTOSTART_DB=${dir_vbox_autostart}

# points the service to the autostart configuration file
VBOXAUTOSTART_CONFIG=${file_autostart_config}
EOF

# -----------------

# create the autostart configuration file

cat > ${file_autostart_config} <<EOF
# Default policy is to deny starting a VM, the other option is "allow"
default_policy = deny

# contains a comma seperated list with usernames
#exception_list =

EOF

# add an entry in ${file_autostart_config} for each account

for a in ${accounts_autostart} ; do
	echo "$a = {
	allow = true
    startup_delay = 10
}" >> ${file_autostart_config}
done

exit



# Every user who wants to enable autostart for individual machines has to set the path to the autostart database directory with:
# VBoxManage setproperty autostartdbpath <Autostart directory>

# VBoxManage startvm --type headless svr


