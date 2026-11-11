#!/bin/sh
# install.sh <base> <version>: dromas installed from the repositories at
# <base> as README.md § Install has it, in this container's distribution, as
# root, then dromas version checked to print <version>. The repo file names
# https://packages.dromas.dev, which a test's <base> replaces.
set -eu
base=$1
version=$2

if command -v apt-get > /dev/null; then
	apt-get update -qq
	apt-get install -y -qq curl > /dev/null
	install -d -m 0755 /etc/apt/keyrings
	curl -fsSL "$base/dromas.asc" -o /etc/apt/keyrings/dromas.asc
	cat > /etc/apt/sources.list.d/dromas.sources <<-EOF
		Types: deb
		URIs: $base/deb
		Suites: stable
		Components: main
		Signed-By: /etc/apt/keyrings/dromas.asc
	EOF
	apt-get update -qq
	apt-get install -y -qq dromas > /dev/null
elif command -v dnf > /dev/null; then
	curl -fsSL "$base/rpm/stable/dromas.repo" |
		sed "s#https://packages.dromas.dev#$base#" > /etc/yum.repos.d/dromas.repo
	dnf install -y -q dromas
elif command -v apk > /dev/null; then
	wget -qO /etc/apk/keys/dromas-packages.rsa.pub "$base/dromas-packages.rsa.pub"
	echo "$base/apk/stable" >> /etc/apk/repositories
	apk add -q dromas
else
	echo "no apt-get, dnf or apk here" >&2
	exit 1
fi

dromas version
dromas version | grep -qF "\"version\":\"$version\""
