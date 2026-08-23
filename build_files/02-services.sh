#!/usr/bin/bash

set -euxo pipefail

# Enable services. GDM was pulled in as a dependent removal in 00-packages.sh
# so it doesn't need disabling here.

systemctl enable nix.mount
systemctl enable nix-daemon.service
systemctl enable greetd
systemctl enable pcscd.socket
systemctl enable mullvad-daemon.service
