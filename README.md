# Seafile server deb packages

> [!WARNING]
> These packages are under heavy development. The packaging slicing may still
> change and the package architecture is not fixed yet — package names, splits
> and layout can change without notice between releases.

Debian packages for running [Seafile Community Edition](https://www.seafile.com) on your system natively without docker. Upstream only ships a docker-based deployment; these packages build the community server from source and integrate it with systemd.

This single source package builds the whole server-side stack. Its main upstream is [seafile-server](https://github.com/haiwen/seafile-server); the other pieces are pulled in by tag as source components and compiled together. It produces these binary packages:

- **seafile-server** — the complete server: the compiled daemons (`seaf-server`, the go `fileserver` and `notification-server`) and the Seahub web frontend with its background tasks (seafevents) and WebDAV (seafdav); Seahub's Python dependencies ship as a bundled virtualenv resolved with [uv](https://docs.astral.sh/uv/) at build time. For a headless server, disable the seahub service.
- **seafile-server-data** — the architecture-independent Seahub application (Django app, prebuilt frontend assets, seafevents, seafdav).
- **seafile-fuse** — optional read-only FUSE filesystem (`seaf-fuse`) presenting the libraries in the object store as regular files.

The RPC library ([libsearpc](https://github.com/haiwen/libsearpc)) comes from the distribution (`libsearpc1t64`, `python3-searpc`).

The desktop and command line clients ([seaf-cli](https://github.com/haiwen/seafile), [seafile-client](https://github.com/haiwen/seafile-client), [SeaDrive](https://github.com/haiwen/seadrive-fuse)) and [SeaDoc](https://github.com/haiwen/sdoc-server) have their own independent version streams and are packaged separately, not from this repository.

## Installation

The easiest way to install is using the apt repository on [apt.crunchy.run/seafile](https://apt.crunchy.run/seafile). Installation instructions are available directly on the repository page.

```bash
sudo apt install curl
curl -fsSL https://apt.crunchy.run/seafile/install.sh | sudo bash -
sudo apt install seafile-server
```

Alternatively, download prebuilt packages from the [releases section](https://github.com/dionysius/seafile-deb/releases) and verify signatures with the [signing-key](signing-key.pub). Packages are automatically built in [Github Actions](https://github.com/dionysius/seafile-deb/actions).

## Configuration

After installation, configure the server by editing `/etc/seafile/seafile.env` (secrets, database, cache, hostname, feature toggles) and `/etc/seafile/seafile.conf`. A random `JWT_PRIVATE_KEY` is generated on first install. Restart afterwards with `systemctl restart seaf-server seahub`.

By default the SQLite backend is used and needs no external service. For the MySQL/MariaDB backend, set the `SEAFILE_MYSQL_DB_*` variables in `seafile.env` and switch `seafile.conf` to the mysql backend. See the [Seafile manual](https://manual.seafile.com/13.0/) for the full configuration reference.

> [!NOTE]
> First-run initialisation of the databases, data directories and the admin account is not yet fully wired for the native install. Track progress in the issues.

## Issues

As this is an alternative installation method, there may be differences from the official docker images. **Please verify any problem is also reproducible with the official docker deployment before reporting upstream.**

- [Seafile forum](https://forum.seafile.com/) and [manual](https://manual.seafile.com/) — for issues with Seafile itself
- [Issues](https://github.com/dionysius/seafile-deb/issues) and [Discussions](https://github.com/dionysius/seafile-deb/discussions) — for issues with or related to these packages

## Security and stability

These packages favour the distribution-native way of running software. Wherever possible they link against system libraries and reuse distribution packages, so they receive the distribution's regular security updates and stability, with newer distributions or backports providing more recent versions.

By default the systemd service is sandboxed, isolating the service from the rest of the system, while the configuration and data directories are restricted to the service's own user. Complex setups may need extra configuration, freely adjustable in the service file.

## Release schedule

This project aims to closely match the releases of upstream. The first release in each minor version series starts as a prerelease with a 3-day waiting period to allow upstream to fix oversights in new features or changes. Subsequent releases follow the same waiting period. After the waiting period has passed, all prereleases are automatically promoted to normal releases. Important releases may skip the waiting period.

## Build source package

This debian source package builds [Seafile server](https://github.com/haiwen/seafile-server) natively on your build environment. No annoying docker! It is managed with [git-buildpackage](https://wiki.debian.org/PackagingWithGit) and follows upstream's own community build recipe from [seafile-docker](https://github.com/haiwen/seafile-docker/tree/master/build/seafile_13.0). You can find the maintaining command summary in [debian/gbp.conf](debian/gbp.conf).

### Requirements

Installed `git-buildpackage` from your apt, clone with it and switch to the folder:

```bash
gbp clone https://github.com/dionysius/seafile-deb.git
cd seafile-deb
```

Installed build dependencies as defined in [debian/control `Build-Depends`](debian/control) (will notify you in the build process otherwise). [`mk-build-deps`](https://manpages.debian.org/testing/devscripts/mk-build-deps.1.en.html) can help you automate the installation, for example:

```bash
mk-build-deps -i -r debian/control -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes"
```

If `nodejs`/`npm` is not recent enough don't forget to look into your `*-updates`/`*-backports` apt sources for newer versions or use a package from [nodesource](https://github.com/nodesource/distributions).

### Build package

There are many arguments to fine-tune the build (see `gbp buildpackage --help` and `dpkg-buildpackage --help`), notable options: `-b` (binary-only, no source files), `-us` (unsigned source package), `-uc` (unsigned .buildinfo and .changes file), for example:

```bash
gbp buildpackage -b -us -uc
```

On successful build packages can now be found in the parent directory `ls ../*.deb`.

## Inspirations and Alternatives

- [Seafile manual: build from source](https://manual.seafile.com/13.0/develop/server/)
- [haiwen/seafile-docker build scripts](https://github.com/haiwen/seafile-docker/tree/master/build)
