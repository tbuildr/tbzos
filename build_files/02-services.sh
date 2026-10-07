#!/usr/bin/bash

set -euxo pipefail

# Enable services. GDM was pulled in as a dependent removal in 00-packages.sh
# so it doesn't need disabling here.

systemctl enable nix.mount
systemctl enable nix-daemon.service
systemctl enable greetd
systemctl enable pcscd.socket
systemctl enable mullvad-daemon.service

# --- firewall: tbzos zone as default; fail the build if it isn't ---
# Replaces Fedora's default zone (Workstation-style zones open 1025-65535).
systemctl enable firewalld.service
grep -q '^DefaultZone=' /etc/firewalld/firewalld.conf
sed -i 's/^DefaultZone=.*/DefaultZone=tbzos/' /etc/firewalld/firewalld.conf
firewall-offline-cmd --check-config
test "$(firewall-offline-cmd --get-default-zone)" = tbzos
test "$(firewall-offline-cmd --zone=tbzos --list-services)" = dhcpv6-client
test -z "$(firewall-offline-cmd --zone=tbzos --list-ports)"
grep -qx 'LLMNR=no' /usr/lib/systemd/resolved.conf.d/50-no-llmnr.conf
