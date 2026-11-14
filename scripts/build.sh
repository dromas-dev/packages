#!/usr/bin/env bash
# build.sh <in> <out>: the repositories' tree in <out>, from fetch.sh's <in>.
#
#   deb/  apt: the .deb files in pool/, indexed by apt-ftparchive into
#         dists/stable/main, its Release signed (InRelease and Release.gpg);
#         a .deb is not signed itself, as Debian's are not.
#         dromas.sources, the source apt reads (deb822).
#   rpm/stable/  dnf: each .rpm signed (rpmsign --addsign), indexed by
#         createrepo_c, repodata/repomd.xml signed (repomd.xml.asc), and
#         dromas.repo.
#   apk/stable/<arch>/  apk: the .apk files as released, named as apk fetches
#         them, indexed by apk index, APKINDEX.tar.gz signed by abuild-sign.
#   dromas.asc, dromas-packages.rsa.pub  the two public keys.
#
# An rpm is signed once: its signature carries the time it was made, and a
# published file never changes, so each one in $PREVIOUS (a tree this script
# built before, with the same key) is carried forward, and only an rpm not
# there is signed. Every rpm in <out> is checked to be its release's package,
# signed by the key.
#
# GNUPGHOME holds the signing key and no other secret key; APK_KEY is the
# path of the apk key, named dromas-packages.rsa, its public half beside it as
# dromas-packages.rsa.pub. Needs apt-ftparchive, rpmsign, createrepo_c, gpg
# and docker, which runs the apk tools in Alpine.
set -euo pipefail
umask 022

in=$(cd "$1" && pwd)
mkdir -p "$2"
out=$(cd "$2" && pwd)
repo=$(cd "$(dirname "$0")/.." && pwd)

fpr=$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr/ { print $10; exit }')
[ -n "$fpr" ] || { echo "no secret key in GNUPGHOME" >&2; exit 1; }
[ "$(basename "$APK_KEY")" = dromas-packages.rsa ] && [ -r "$APK_KEY.pub" ] ||
	{ echo "APK_KEY: dromas-packages.rsa with its .pub beside it" >&2; exit 1; }

gpg --batch --armor --export "$fpr" > "$out/dromas.asc"
install -m 0644 "$APK_KEY.pub" "$out/dromas-packages.rsa.pub"

# apt
pool=$out/deb/pool/main/d/dromas
mkdir -p "$pool"
cp "$in"/*/*.deb "$pool/"
(
	cd "$out/deb"
	for arch in amd64 arm64; do
		dir=dists/stable/main/binary-$arch
		mkdir -p "$dir"
		apt-ftparchive --arch "$arch" packages pool > "$dir/Packages"
		gzip -9nk "$dir/Packages"
	done
	apt-ftparchive \
		-o APT::FTPArchive::Release::Origin=Dromas \
		-o APT::FTPArchive::Release::Label=Dromas \
		-o APT::FTPArchive::Release::Suite=stable \
		-o APT::FTPArchive::Release::Codename=stable \
		-o "APT::FTPArchive::Release::Architectures=amd64 arm64" \
		-o APT::FTPArchive::Release::Components=main \
		-o "APT::FTPArchive::Release::Description=Dromas packages" \
		release dists/stable > "$in/Release"
	mv "$in/Release" dists/stable/Release
	gpg --batch --yes --local-user "$fpr" --clearsign -o dists/stable/InRelease dists/stable/Release
	gpg --batch --yes --local-user "$fpr" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
)

# dnf
rpms=$out/rpm/stable
mkdir -p "$rpms"
db=$(mktemp -d)
trap 'rm -rf "$db"' EXIT
rpmkeys --dbpath "$db" --import "$out/dromas.asc"
header() { rpm --dbpath "$db" -qp --nosignature --qf '%{SHA256HEADER}' "$1"; }
for file in "$in"/*/*.rpm; do
	name=$(basename "$file")
	if [ -n "${PREVIOUS:-}" ] && [ -e "$PREVIOUS/rpm/stable/$name" ]; then
		cp "$PREVIOUS/rpm/stable/$name" "$rpms/$name"
		echo "carried: $name"
	else
		cp "$file" "$rpms/$name"
		rpmsign --addsign --define "_gpg_name $fpr" "$rpms/$name"
		echo "signed: $name"
	fi
	[ "$(header "$file")" = "$(header "$rpms/$name")" ] ||
		{ echo "$name: not the release's package" >&2; exit 1; }
	rpmkeys --dbpath "$db" --checksig "$rpms/$name"
done
createrepo_c --quiet "$rpms"
gpg --batch --yes --local-user "$fpr" --armor --detach-sign -o "$rpms/repodata/repomd.xml.asc" "$rpms/repodata/repomd.xml"
cp "$repo/rpm/dromas.repo" "$rpms/dromas.repo"
cp "$repo/deb/dromas.sources" "$out/deb/dromas.sources"

# apk
for arch in x86_64 aarch64; do
	dir=$out/apk/stable/$arch
	mkdir -p "$dir"
	for file in "$in"/*/*_"$arch".apk; do
		name=$(basename "$file" "_$arch.apk")
		cp "$file" "$dir/${name/_/-}.apk"
	done
done
apk_image=$(docker build -q -f "$repo/scripts/apk-index.Dockerfile" "$repo/scripts")
docker run --rm -v "$out/apk/stable:/apk" -v "$(dirname "$APK_KEY"):/keys:ro" "$apk_image" sh -ec '
	for dir in /apk/*/; do
		cd "$dir"
		apk index --quiet --allow-untrusted -o APKINDEX.tar.gz *.apk
		abuild-sign -q -t RSA256 -k /keys/dromas-packages.rsa APKINDEX.tar.gz
	done'

# nginx serves as its own user: every file is read by others, every directory
# entered.
unreadable=$(find "$out" \( -type f ! -perm -o+r \) -o \( -type d ! -perm -o+rx \))
[ -z "$unreadable" ] || { echo "not readable by nginx:" >&2; echo "$unreadable" >&2; exit 1; }
