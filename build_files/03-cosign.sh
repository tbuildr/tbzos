#!/usr/bin/bash

set -euxo pipefail

# Verify tbzos container images using this repository's Cosign key.
#
# The policy edit preserves Bazzite's existing policy and adds verification for
# tbzos. Repo-wide, so both variants (tagged amd-* / nvidia-* in the same repo)
# are covered by matchRepository without touching this block per variant.
#
install -d -m 0755 /etc/pki/containers /etc/containers/registries.d
install -m 0644 /tmp/tbzos.pub /etc/pki/containers/tbzos.pub
rm -f /tmp/tbzos.pub
policy_tmp="$(mktemp)"
jq '.transports //= {} | .transports.docker //= {} | .transports.docker["ghcr.io/tbuildr/tbzos"] = [{"type":"sigstoreSigned","keyPath":"/etc/pki/containers/tbzos.pub","signedIdentity":{"type":"matchRepository"}}]' \
  /etc/containers/policy.json >"${policy_tmp}"

jq empty "${policy_tmp}"
install -m 0644 "${policy_tmp}" /etc/containers/policy.json
rm -f "${policy_tmp}"
printf '%s\n' \
  'docker:' \
  '  ghcr.io/tbuildr/tbzos:' \
  '    use-sigstore-attachments: true' \
  >/etc/containers/registries.d/tbzos.yaml

rm -rf /tmp/tbzos-build_files
