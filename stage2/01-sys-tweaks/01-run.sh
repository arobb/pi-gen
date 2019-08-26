#!/bin/bash -e

install -m 755 files/resize2fs_once	"${ROOTFS_DIR}/etc/init.d/"

install -d				"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d"
install -m 644 files/ttyoutput.conf	"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d/"

install -m 644 files/50raspi		"${ROOTFS_DIR}/etc/apt/apt.conf.d/"

install -m 644 files/console-setup   	"${ROOTFS_DIR}/etc/default/"

install -m 755 files/rc.local		"${ROOTFS_DIR}/etc/"

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable nfs-common
systemctl disable rpcbind
if [ "${ENABLE_SSH}" == "1" ]; then
	systemctl enable ssh
else
	systemctl disable ssh
fi
systemctl enable regenerate_ssh_host_keys
EOF

if [ "${USE_QEMU}" = "1" ]; then
	echo "enter QEMU mode"
	install -m 644 files/90-qemu.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
	on_chroot << EOF
systemctl disable resize2fs_once
EOF
	echo "leaving QEMU mode"
else
	on_chroot << EOF
systemctl enable resize2fs_once
EOF
fi

on_chroot <<EOF
for GRP in input spi i2c gpio; do
	groupadd -f -r "\$GRP"
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser $FIRST_USER_NAME \$GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
EOF

on_chroot << EOF
usermod --pass='*' root
EOF

rm -f "${ROOTFS_DIR}/etc/ssh/"ssh_host_*_key*

# on_chroot << EOF
# patch << 'EOG' /boot/config.txt
# --- config.txt	2019-01-17 06:23:28.000000000 -0800
# +++ config copy.txt	2019-01-16 22:56:44.000000000 -0800
# @@ -11,10 +11,10 @@
#
#  # uncomment the following to adjust overscan. Use positive numbers if console
#  # goes off screen, and negative if there is too much border
# -#overscan_left=16
# -#overscan_right=16
# -#overscan_top=16
# -#overscan_bottom=16
# +overscan_left=16
# +overscan_right=16
# +overscan_top=16
# +overscan_bottom=16
#
#  # uncomment to force a console size. By default it will be display's size minus
#  # overscan.
# EOG
# EOF

# on_chroot << EOF
# patch << 'EOG' /boot/config.txt
# --- /boot/config.txt	2017-08-20 00:44:26.000000000 +0000
# +++ ./config.txt	2019-08-19 04:36:43.790494373 +0000
# @@ -43,9 +43,9 @@
#  #arm_freq=800
#
#  # Uncomment some or all of these to enable the optional hardware interfaces
# -#dtparam=i2c_arm=on
# -#dtparam=i2s=on
# -#dtparam=spi=on
# +dtparam=i2c_arm=on
# +dtparam=i2s=on
# +dtparam=spi=on
#
#  # Uncomment this to enable the lirc-rpi module
#  #dtoverlay=lirc-rpi
# EOG
# EOF

# on_chroot << EOF
# # Shim doesn't install as root
# su pi
# curl https://raw.githubusercontent.com/arobb/pimoroni-onoffshim-headless/master/onoffshim.sh | bash -s -- -y
# if [[ "$(whoami)" != "root" ]]; then
#   exit # Drop su
# fi
# EOF

install -m 744 files/sensor-pod-install-playbook.yml		"${ROOTFS_DIR}/tmp/"
on_chroot << EOF
ansible-playbook --connection=local /tmp/sensor-pod-install-playbook.yml
EOF
