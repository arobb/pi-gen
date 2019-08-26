#!/bin/bash -e
on_chroot << EOF
ansible-playbook --connection=local 127.0.0.1 $PWD/files/sensor-pod-install-playbook.yml
EOF
