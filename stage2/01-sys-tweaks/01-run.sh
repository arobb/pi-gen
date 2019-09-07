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

echo "Update CA Certificate package in this environment"
if [ ! -f /tmp/ca-certs-updated.touch ]; then
  apt update && apt install -y --reinstall ca-certificates
  result=$?

  if [ "$result" -ne "0" ]; then
    echo "Update of CA Certificates failed, cannot continue Sensor Pod build"
    exit 1
  else
    touch /tmp/ca-certs-updated.touch
  fi
fi

echo "Download the shim installer"
if [ ! -f files/onoffshim.sh ]; then
  curl --silent -L --output files/onoffshim.sh https://raw.githubusercontent.com/arobb/pimoroni-onoffshim-headless/master/onoffshim.sh
  result=$?

  if [ "$result" -ne "0" ]; then
    echo "Shim download failed, cannot continue Sensor Pod build"
    exit 1
  fi
fi

echo "Run Sensor Pod Ansible Playbook"
install -m 744 files/sensor-pod-install-playbook.yml		"${ROOTFS_DIR}/tmp/"
install -m 744 files/boot-config.txt.patch		"${ROOTFS_DIR}/tmp/"
install -m 755 files/onoffshim.sh		"${ROOTFS_DIR}/tmp/"
on_chroot << EOF
ansible-playbook --connection=local /tmp/sensor-pod-install-playbook.yml
EOF
