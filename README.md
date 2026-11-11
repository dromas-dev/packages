# packages.dromas.dev

apt, dnf and apk repositories of `dromas`, the command-line client of
[Dromas](https://dromas.dev), built from each release of
[dromas-dev/dromas-client](https://github.com/dromas-dev/dromas-client) by
[`publish.yml`](.github/workflows/publish.yml) and served at
`https://packages.dromas.dev`. They hold the client's newest releases, amd64
and arm64.

## Install

Each format's key is checked against this page, read on GitHub, never against
the host it vouches for: § The keys.

### Debian and Ubuntu

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://packages.dromas.dev/dromas.asc -o /etc/apt/keyrings/dromas.asc
gpg --show-keys /etc/apt/keyrings/dromas.asc
sudo tee /etc/apt/sources.list.d/dromas.sources > /dev/null <<'EOF'
Types: deb
URIs: https://packages.dromas.dev/deb
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/dromas.asc
EOF
sudo apt update
sudo apt install dromas
```

### Fedora, RHEL, AlmaLinux, Rocky Linux

```sh
sudo curl -fsSL https://packages.dromas.dev/rpm/stable/dromas.repo -o /etc/yum.repos.d/dromas.repo
sudo dnf install dromas
```

dnf prints the key's fingerprint as it imports it; answer yes only if it is
the GPG key's below.

### Alpine

```sh
wget -qO /etc/apk/keys/dromas-packages.rsa.pub https://packages.dromas.dev/dromas-packages.rsa.pub
sha256sum /etc/apk/keys/dromas-packages.rsa.pub
echo https://packages.dromas.dev/apk/stable >> /etc/apk/repositories
apk add dromas
```

## The keys

| File | Key | Signs | Check |
|---|---|---|---|
| [`keys/dromas.asc`](keys/dromas.asc), served as `/dromas.asc` | GPG, RSA 4096, `Dromas packages <dtype@dtype.org>`, expires 2028-11-10 | apt's `Release` (`InRelease`, `Release.gpg`), each `.rpm`, each `repomd.xml` (`repomd.xml.asc`) | fingerprint `ED32 6F51 D394 BA2D 5EE1  CFC7 2608 D731 31C7 9706` |
| [`keys/dromas-packages.rsa.pub`](keys/dromas-packages.rsa.pub), served as `/dromas-packages.rsa.pub` | RSA 4096 | each `APKINDEX.tar.gz` | SHA-256 of the file `74abfdd4fd70d7aeaac1e742a41b7403a813cd3657565b938b94cdddde1d7c38` |

## What is served

| Path | Format |
|---|---|
| `/deb/` | apt: suite `stable`, component `main`; `pool/` holds the `.deb` files |
| `/rpm/stable/` | dnf: the `.rpm` files, `repodata/`, and `dromas.repo` |
| `/apk/stable/<arch>/` | apk, for `x86_64` and `aarch64`: the `.apk` files and `APKINDEX.tar.gz` |

A package is named by its version and never changes once served; the indexes,
the repo file and the keys change with each release (`nginx.conf` sends each
its `Cache-Control`).

## How it is built

`publish.yml` runs on each push to `main`, on each pull request, and by hand
after a client release:

1. [`scripts/fetch.sh`](scripts/fetch.sh) downloads the `.deb`, `.rpm` and
   `.apk` files of the client's newest releases and checks each against its
   attestation from that tag's run of the client's `release.yml`.
2. [`scripts/build.sh`](scripts/build.sh) indexes and signs them. A `.deb` and
   an `.apk` are served as released, their hashes in the signed indexes, as
   Debian's and Alpine's indexes vouch for theirs. An `.rpm` carries this
   repository's signature, made once: the rpms of the image last pushed carry
   forward, and only a new release's are signed.
3. The [`Dockerfile`](Dockerfile) copies the tree into NGINX's unprivileged
   image. [`test/install.sh`](test/install.sh) installs `dromas` from it, as §
   Install has it, in Debian, Ubuntu, Fedora, AlmaLinux and Alpine containers.
4. On `main`, the image is pushed to `ghcr.io/dromas-dev/dromas-packages`, for
   amd64 and arm64, with an attestation of its build:

   ```sh
   gh attestation verify oci://ghcr.io/dromas-dev/dromas-packages@<digest> -R dromas-dev/packages
   ```

The private keys are secrets of this repository's environment `sign`, which
only `main` deploys from; any other run signs with keys made for that run and
pushes nothing.

## Licence

[Apache-2.0](LICENSE).
