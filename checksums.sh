#!/usr/bin/env bash
#
# Regenerate the .sha1/.md5 sidecars maven clients check.
#
#   ./checksums.sh
#
# Gradle verifies these when present and fails the build on a mismatch, which
# is the point: a truncated raw.githubusercontent fetch would otherwise land as
# a corrupt AAR and fail much later, somewhere confusing.
#
# Run this after replacing or adding any artifact.
set -e

cd "$(dirname "$0")/maven"

find . -type f \( -name '*.aar' -o -name '*.pom' -o -name 'maven-metadata.xml' \) -print0 |
    while IFS= read -r -d '' f; do
        sha1sum "$f" | cut -d' ' -f1 > "$f.sha1"
        md5sum "$f" | cut -d' ' -f1 > "$f.md5"
        echo "checksummed $f"
    done
