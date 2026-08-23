#!/usr/bin/bash

set -euxo pipefail

# greetd-home.conf creates /var/lib/greetd on first boot.
#
# The greetd package ships /usr/lib/tmpfiles.d/greetd.conf, but its entry is:
#   Z  /var/lib/greetd -    greetd greetd -   -
# `Z` only recursively fixes ownership/permissions on a path that ALREADY
# exists - it never creates one. On ostree/bootc builds the directory isn't
# there, so nothing creates it and greetd has no home. Ours uses `d`, which
# creates it:
#   d  /var/lib/greetd 0700 greetd greetd -
#
# The two files coexist rather than conflict: tmpfiles.d entries run in lexical
# order, so greetd.conf (`Z`, no-op on a missing path) runs first, then
# greetd-home.conf (`d`) creates it.
#
# Note the vendor file deliberately passes `-` for Mode - see its own comment
# about dynamic users/groups not being stable across builds. We assert 0700
# explicitly instead. If greetd upstream ever changes the permissions it wants,
# ours will silently win; drop to `-` in the Mode column if that becomes a
# problem and let `Z` handle it.
install -d -m 0755 /usr/lib/tmpfiles.d /etc/greetd /etc/nix /etc/niri
install -m 0644 /tmp/tbzos-config/greetd/greetd-home.conf /usr/lib/tmpfiles.d/greetd-home.conf
install -m 0644 /tmp/tbzos-config/greetd/config.toml /etc/greetd/config.toml
install -m 0644 /tmp/tbzos-config/niri/config.kdl /etc/niri/config.kdl
install -m 0644 /tmp/tbzos-config/nix/nix.conf /etc/nix/nix.conf
install -m 0644 /tmp/tbzos-config/systemd/nix-store-root.service \
  /usr/lib/systemd/system/nix-store-root.service
install -m 0644 /tmp/tbzos-config/systemd/nix.mount \
  /usr/lib/systemd/system/nix.mount
install -m 0644 /tmp/tbzos-assets/tbzos-fastfetch.png \
  /usr/share/fastfetch/os-logo.png
install -m 0644 /tmp/tbzos-assets/tbzos-plymouth.png \
  /usr/share/plymouth/themes/spinner/watermark.png
rm -rf /tmp/tbzos-config /tmp/tbzos-assets
