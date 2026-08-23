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
baked into the image along with Ollama service and container quadlet.

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

If you've run the boot splash branding step below
(`rpm-ostree initramfs
--enable`), your deployment has a local rpm-ostree
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

### Mullvad VPN

Baked into the image (`mullvad-daemon` enabled by default). Mullvad officially
lists Fedora Atomic as unsupported — that's specifically about `rpm-ostree`'s
_live_ package layering, which remaps `/opt` content in a way that breaks its
daemon's SELinux context. Installing at container-build time, where `/opt` is a
real (not symlinked) directory in this image, appears to avoid that problem —
confirmed by checking `systemctl status mullvad-daemon` after boot. If you hit
issues, `rpm-ostree
status` will show whether anything about the deployment
looks unusual.

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
