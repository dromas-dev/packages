#!/usr/bin/env bash
# fetch.sh <count> <dir>: the .deb, .rpm and .apk files of the newest <count>
# releases of dromas-dev/dromas-client that carry them, into <dir>/<tag>/,
# each checked against its attestation from that tag's release workflow, and
# <dir>/tags, the tags oldest first. Needs gh, signed in (GH_TOKEN in CI).
set -euo pipefail

count=$1
dir=$2
client=dromas-dev/dromas-client

mkdir -p "$dir"
tags=()
while read -r tag; do
	n=$(gh release view "$tag" -R "$client" --json assets \
		--jq '[.assets[].name | select(test("\\.(deb|rpm|apk)$"))] | length')
	[ "$n" -gt 0 ] && tags+=("$tag")
	[ "${#tags[@]}" -eq "$count" ] && break
done < <(gh release list -R "$client" --exclude-drafts --exclude-pre-releases \
	--limit 100 --json tagName --jq '.[].tagName')
[ "${#tags[@]}" -gt 0 ] || { echo "no release of $client carries packages" >&2; exit 1; }

: > "$dir/tags"
for ((i = ${#tags[@]} - 1; i >= 0; i--)); do
	tag=${tags[i]}
	gh release download "$tag" -R "$client" -D "$dir/$tag" \
		-p '*.deb' -p '*.rpm' -p '*.apk'
	for file in "$dir/$tag"/*; do
		gh attestation verify "$file" -R "$client" \
			--signer-workflow "$client/.github/workflows/release.yml" \
			--source-ref "refs/tags/$tag" > /dev/null
		echo "attested: $file"
	done
	echo "$tag" >> "$dir/tags"
done
