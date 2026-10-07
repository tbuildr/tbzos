# tbzos

tbzos is my personal, opinionated Bazzite-derived bootable container image.

It replaces GNOME with **Niri** (Wayland tiling window compositor) +
**Noctalia** (shell) + `greetd`/`tuigreet` (login), while keeping Bazzite's
gaming stack: Steam, gamescope, gamemode, MangoHud. Lutris and Waydroid are
removed — I don't use them. Nix is installed for
[Home Manager](https://github.com/tbuildr/tnxhm), which manages my user-level
dotfiles and packages separately from this image. I prefer this declarative
approach than using brew. I keep flatpak use to a minimum. You will also get
Brave Browser, Chromium, Yubikey Manager, Mullvad-VPN that are intentionally
baked into the image along with Ollama service and container quadlet. Inbound
networking is locked down by default: a deny-by-default firewalld zone and no
LLMNR/mDNS (see [Firewall and LAN hardening](#firewall-and-lan-hardening)).

Built with the
[Universal Blue image-template](https://github.com/ublue-os/image-template).

<p align="center">
  <img src="assets/tbzos.png" alt="tbzOS logo" width="700">
</p>

> [!WARNING]
> tbzos is a personal project — not official Bazzite, Universal Blue, Niri or
> Noctalia. No warranty. Understand Fedora Atomic rebasing, upgrades and
> rollback before using it.

## Variants

tbzos publishes two flavors from the same Containerfile, selected by GPU:

| Tag             | Base                                                | Use on      |
| --------------- | --------------------------------------------------- | ----------- |
| `amd-latest`    | `ghcr.io/ublue-os/bazzite-gnome:stable`             | AMD GPUs    |
| `nvidia-latest` | `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable` | Nvidia GPUs |

Both also get dated/SHA-suffixed tags (`amd-YYYYMMDD-<sha>`, etc.) for pinning
to a specific build. Pick the tag matching your GPU — rebasing to the wrong one
will not give you a working graphics stack.

## Rebasing to tbzos

**Check first:** confirm your GPU matches the variant you're targeting, and note
your current image (`rpm-ostree status`) so you have something to return to.

**Bootstrap trust** (first time only — tbzos's Cosign key isn't trusted yet):

```sh
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/tbuildr/tbzos:amd-latest
# or :nvidia-latest
systemctl reboot
```

**Switch to the signed origin** (after booting into tbzos):

```sh
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/tbuildr/tbzos:amd-latest
systemctl reboot
```

A system with no layered packages can instead use `bootc switch` directly for
either stage:

```sh
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tbuildr/tbzos:amd-latest
systemctl reboot
```

Only rebase from a GitHub Actions run that completed **build, push, and Cosign
sign** — a failed sign step can leave a pushed-but-unsigned image.

### Boot splash branding

The custom Plymouth theme (shown at the LUKS unlock prompt) doesn't take effect
from the Containerfile build — Bazzite's branding requires a live, client-side
`rpm-ostree` operation with no build-time equivalent. Run this **once** after
your first switch to tbzos (confirmed working — takes effect from the next
reboot onward):

```sh
sudo rpm-ostree initramfs --enable --reboot
```

## Updating

If you've run the boot splash branding step above
(`rpm-ostree initramfs --enable`), your deployment has a local rpm-ostree
modification, and **`bootc upgrade` will refuse** with "Deployment contains
local rpm-ostree modifications." Use `rpm-ostree upgrade` instead:

```sh
sudo rpm-ostree upgrade
systemctl reboot
```

Only use plain `bootc upgrade` if you've never run that step (or have since run
`sudo rpm-ostree reset` to clear all local modifications):

```sh
sudo bootc upgrade
systemctl reboot
```

## Niri configuration

tbzos ships a default Niri config at `/etc/niri/config.kdl` (Noctalia
autostart + sane defaults) so a fresh rebase lands in a working session.

Niri only reads this as a fallback — the moment `~/.config/niri/config.kdl`
exists for your user, it takes priority and the system default is ignored
entirely. To customize your own setup, copy it as your starting point:

    mkdir -p ~/.config/niri
    cp /etc/niri/config.kdl ~/.config/niri/config.kdl

(I manage mine via [Home Manager](https://github.com/tbuildr/tnxhm) instead.)

## Layered packages

Use `rpm-ostree install` for host-level software that can't go cleanly in the
Containerfile. Trade-off: layered packages can block an upgrade on dependency
conflicts, and may need removing before a base image change.

```sh
rpm-ostree status                     # inspect
sudo rpm-ostree uninstall PACKAGE     # remove one
sudo rpm-ostree reset                 # remove all layered packages/overrides
```

## Rollback

```sh
sudo rpm-ostree rollback
systemctl reboot
```

Or pick the previous deployment from the bootloader menu. Pin a known-good
deployment to keep it around indefinitely:

```sh
sudo ostree admin pin 0          # pin
rpm-ostree status -v             # find index
sudo ostree admin pin --unpin INDEX
```

## Returning to another image

```sh
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/ORIGINAL-IMAGE:stable
systemctl reboot
```

Rebasing across substantially different desktops can leave stale user config
behind — a clean profile is sometimes worth it.

## Mullvad VPN

Baked into the image (`mullvad-daemon` enabled by default). Mullvad officially
lists Fedora Atomic as unsupported — that's specifically about `rpm-ostree`'s
_live_ package layering, which remaps `/opt` content in a way that breaks its
daemon's SELinux context. Installing at container-build time, where `/opt` is a
real (not symlinked) directory in this image, appears to avoid that problem —
confirmed by checking `systemctl status mullvad-daemon` after boot. If you hit
issues, `rpm-ostree
status` will show whether anything about the deployment
looks unusual.

## Firewall and LAN hardening

The image now ships its own firewalld zone, **`tbzos`**, as the default zone,
and turns off LLMNR and mDNS. Nothing on a desktop needs to accept connections
from the LAN, so the image doesn't.

| What                                                                                                   | In the image                                        | Source in this repo                |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------- | ---------------------------------- |
| Zone `tbzos`: inbound **only DHCPv6 replies**; everything else rejected; no forwarding within the zone | `/usr/lib/firewalld/zones/tbzos.xml`                | `config/firewalld/tbzos.xml`       |
| `DefaultZone=tbzos`, `firewalld` enabled                                                               | `/etc/firewalld/firewalld.conf` (image default)     | `build_files/02-services.sh`       |
| `LLMNR=no`, `MulticastDNS=no` (both spoofable on a LAN)                                                | `/usr/lib/systemd/resolved.conf.d/50-no-llmnr.conf` | `config/resolved/50-no-llmnr.conf` |

- It replaces the base image's default zone. Fedora's desktop zones open TCP/UDP
  1025–65535 to the whole LAN.
- **The build fails** if the result is wrong: `02-services.sh` runs
  `firewall-offline-cmd --check-config` and checks the default zone, that
  `dhcpv6-client` is the only service, that no ports are open and that the LLMNR
  drop-in is there.
- The zone is **generic**: no addresses, interfaces or hostnames, so it fits any
  machine.
- Outbound is unrestricted. Mullvad uses its own nftables table, separate from
  firewalld's.
- **Mullvad lockdown mode is per machine**, not baked in. It lives in Mullvad's
  own settings, and baking it in would block a new install before it signs in:
  `mullvad lockdown-mode set on`.

**Side effects.** Anything that waits for LAN connections is blocked, for
example Steam Remote Play and local game transfers (`27036`), KDE Connect, a LAN
game server or `.local` name lookups through resolved. If one machine needs one
of these, open it **locally** on that machine:

```sh
sudo firewall-cmd --permanent --zone=tbzos --add-service=steam-streaming   # example
sudo firewall-cmd --reload
```

That writes a copy of the zone to `/etc/firewalld/zones/tbzos.xml`, which takes
precedence over the image's. It shows up in `sudo ostree admin config-diff`, and
from then on that machine no longer gets image updates to the zone. Delete the
`/etc` copy to go back to the image's zone. Anything every tbzos machine needs
goes in `config/firewalld/tbzos.xml` instead.

**Checking a machine:**

```sh
firewall-cmd --get-default-zone                          # tbzos
firewall-cmd --get-active-zones                          # tbzos: <your interface>
firewall-cmd --zone=tbzos --list-all                     # services: dhcpv6-client, ports: (none), forward: no
for u in $(nmcli -g UUID connection show --active); do nmcli -g connection.id,connection.zone connection show "$u"; done   # zone empty = default
resolvectl status | grep -E 'LLMNR|MulticastDNS'         # -LLMNR -mDNS
sudo ostree admin config-diff | grep -E 'firewalld|resolved'   # local overrides, ideally none
```

A NetworkManager connection with its own `connection.zone` ignores the default.
Clear it with `sudo nmcli connection modify "<name>" connection.zone ""`.

**Checking an image before publishing it:**

```sh
IMG=localhost/tbzos:latest
podman run --rm "$IMG" firewall-offline-cmd --get-default-zone           # tbzos
podman run --rm "$IMG" firewall-offline-cmd --zone=tbzos --list-all
podman run --rm "$IMG" cat /usr/lib/systemd/resolved.conf.d/50-no-llmnr.conf
```

**Moving from a hand-made setup.** On a machine where the zone or the drop-in
were created by hand before this, remove the local copies after upgrading, so
the image is the only source:

```sh
sudo ostree admin config-diff | grep -E 'firewalld|resolved'   # see what's local first
sudo rm -f /etc/firewalld/zones/tbzos.xml /etc/firewalld/zones/tbzos.xml.old
sudo rm -f /etc/systemd/resolved.conf.d/50-no-llmnr.conf
sudo firewall-cmd --reload && sudo systemctl restart systemd-resolved
```

`/etc` stays writable by root on any atomic system. The image stops accidental
drift and makes rollback reliable, but it doesn't protect against someone who
already has root. `config-diff` is how you spot local changes.

## Updating Universal Blue template

See [docs/UPDATING.md](docs/UPDATING.md) for the procedure to sync this image
with upstream changes.

## Credits

Built on
[Universal Blue's image-template](https://github.com/ublue-os/image-template)
and [Bazzite](https://bazzite.gg/).

Also relies on: [Fedora](https://fedoraproject.org/) ·
[bootc](https://bootc-dev.github.io/bootc/) ·
[rpm-ostree](https://coreos.github.io/rpm-ostree/) ·
[Niri](https://github.com/YaLTeR/niri) ·
[Noctalia](https://github.com/noctalia-dev/noctalia-shell) ·
[Nix](https://nixos.org/) ·
[Home Manager](https://github.com/nix-community/home-manager) ·
[Sigstore](https://www.sigstore.dev/) /
[Cosign](https://github.com/sigstore/cosign)

Not affiliated with or endorsed by any of the above.
