#!/usr/bin/env bash
# publish-image.sh — build the cloud-cypress NixOS image, upload to GCS,
# register as a GCE image, and prune old image versions.
#
# Re-run whenever you change nixos-workbenches/nixos-servers/hosts/cloud-cypress/
# or any module it imports (notably jenkins-agent.nix, cloud-metadata.nix).
#
# Prerequisites:
#   - bootstrap-gcp.sh all  has been run (bucket + SA exist)
#   - macOS users: nix remote builder configured to xiao-mei
#     (see ~/Workspace/nixos-workbenches/macos/nix-remote-builder.md)
#   - gcloud auth login  done
#
# Doc references:
#   nixos-generators (legacy, still works)        https://github.com/nix-community/nixos-generators
#   nixos-rebuild build-image (25.05+ replacement) https://nix.dev/manual/nixos/stable/configuration/building-image
#   GCE custom image import                       https://cloud.google.com/compute/docs/import/import-existing-image
#   gcloud compute images create                  https://cloud.google.com/sdk/gcloud/reference/compute/images/create
#   Image families                                https://cloud.google.com/compute/docs/images/image-families-best-practices

set -euo pipefail

PROJECT="${PROJECT:-danb-ubuntu-k0s}"
ZONE="${ZONE:-europe-west1-b}"
REGION="${REGION:-${ZONE%-*}}"
BUCKET="${BUCKET:-${PROJECT}-ci-images}"
FAMILY="${FAMILY:-cloud-cypress}"
KEEP="${KEEP:-3}"                                          # how many old images to retain after publish
NIXOS_DIR="${NIXOS_DIR:-$HOME/Workspace/nixos-workbenches/nixos-servers}"
FLAKE_OUTPUT="${FLAKE_OUTPUT:-cloud-cypress-gce}"

log() { printf '\033[1;34m[publish-image]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[publish-image]\033[0m %s\n' "$*" >&2; exit 1; }

# ───────── 1. build (nix-generated GCE tarball: disk.raw inside .tar.gz)

log "building .#${FLAKE_OUTPUT} in $NIXOS_DIR"
[[ -d "$NIXOS_DIR" ]] || die "NIXOS_DIR=$NIXOS_DIR not a directory — set NIXOS_DIR env or symlink"

pushd "$NIXOS_DIR" > /dev/null
# Use the fully-qualified packages.x86_64-linux path so this works from
# any host system. With a bare `.#cloud-cypress-gce`, nix resolves
# against packages.<currentSystem>.* first — and we only declare the
# package under x86_64-linux (it's a Linux GCE image; building it on
# darwin is the whole reason we set up the remote builder).
nix build ".#packages.x86_64-linux.${FLAKE_OUTPUT}" --print-build-logs

# nixos-generators's gce format produces a directory containing exactly one
# *-x86_64-linux.raw.tar.gz file. Resolve the absolute path.
TARBALL=$(find -L result -maxdepth 2 -name '*.raw.tar.gz' | head -1)
[[ -n "$TARBALL" && -f "$TARBALL" ]] || die "no raw.tar.gz under result/ — check the build output"
log "built: $TARBALL ($(du -h "$TARBALL" | cut -f1))"

# ───────── 2. upload to GCS

DEST="gs://${BUCKET}/$(basename "$TARBALL" | sed "s/^/$(date +%Y%m%d-%H%M%S)-/")"
log "uploading to $DEST"
gcloud storage cp "$TARBALL" "$DEST"

popd > /dev/null

# ───────── 3. register as a GCE image, joined to FAMILY

# Image names must be ≤63 chars, lowercase, hyphens — use timestamp suffix.
# GCE image families let `cloud-fleet.sh` reference `family/cloud-cypress`
# and always resolve to the newest image in the family. New images bump
# the family pointer automatically; old images linger until pruned (step 4).
# Best practice: https://cloud.google.com/compute/docs/images/image-families-best-practices
IMAGE_NAME="${FAMILY}-$(date +%Y%m%d-%H%M%S)"

log "registering GCE image: $IMAGE_NAME (family=$FAMILY)"
gcloud compute images create "$IMAGE_NAME" \
  --source-uri="$DEST" \
  --family="$FAMILY" \
  --description="utro CI Cypress worker, built $(date -u +%FT%TZ) from nixos-workbenches" \
  --project="$PROJECT" \
  --storage-location="$REGION"

# ───────── 4. retention: keep only the $KEEP most recent images in the family

log "pruning images in family=$FAMILY, keeping $KEEP newest"
all=$(gcloud compute images list \
  --project="$PROJECT" \
  --filter="family=$FAMILY" \
  --sort-by="~creationTimestamp" \
  --format='value(name)')

# Portable to bash 3.2 (which macOS ships) — readarray/mapfile aren't
# available there. The `[ -n "$line" ]` guard handles the trailing
# newline that <<< adds to the heredoc result.
names=()
while IFS= read -r line; do
  [ -n "$line" ] && names+=("$line")
done <<< "$all"
to_keep=( "${names[@]:0:$KEEP}" )
to_delete=( "${names[@]:$KEEP}" )

if [[ "${#to_delete[@]}" -gt 0 ]]; then
  log "deleting ${#to_delete[@]} older image(s): ${to_delete[*]}"
  # `gcloud compute images delete` only accepts a single name at a time
  # if the names live in the same project. Loop instead of xargs.
  for img in "${to_delete[@]}"; do
    gcloud compute images delete "$img" --project="$PROJECT" --quiet || true
  done
else
  log "nothing to prune (have ${#names[@]} image(s), keeping $KEEP)"
fi

# ───────── 5. summary

log "✓ published. cloud-fleet.sh will now provision VMs from this image."
gcloud compute images describe-from-family "$FAMILY" \
  --project="$PROJECT" \
  --format='table(name,creationTimestamp,diskSizeGb,family)'

cat <<EOF

To force a rebuild for the current in-flight Jenkins build to use the new image,
re-trigger it. Builds already in their Provision Cloud Fleet stage stay on
the image they started with (GCE resolves family/ to a specific image ID at
instance-create time).
EOF
