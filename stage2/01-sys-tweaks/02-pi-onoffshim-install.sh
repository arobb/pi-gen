#!/bin/bash -e
on_chroot << EOF
curl https://get.pimoroni.com/onoffshim | bash
EOF
