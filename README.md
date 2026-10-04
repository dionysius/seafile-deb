# Seafile server deb packages

> [!WARNING]
> These packages are under heavy development. The packaging slicing may still
> change and the package architecture is not fixed yet — package names, splits
> and layout can change without notice between releases.

Easy to install and highly configurable debian packages for running [Seafile Community Edition](https://www.seafile.com) on your system natively without docker. Out of the box it can be installed and built on Debian stable and latest Ubuntu LTS.

## Installation

The easiest way to install seafile is using the apt repository on [apt.crunchy.run/seafile](https://apt.crunchy.run/seafile). Installation instructions are available directly on the repository page.

For detailed installation guides, see the [Installation Wiki](https://github.com/dionysius/seafile-deb/wiki/Installation).

Quick installation:

```bash
sudo apt install curl
curl -fsSL https://apt.crunchy.run/seafile/install.sh | sudo bash -
sudo apt install seafile-server
```

Alternatively, download prebuilt packages from the [releases section](https://github.com/dionysius/seafile-deb/releases) and verify signatures with the [signing-key](signing-key.pub). Packages are automatically built in [Github Actions](https://github.com/dionysius/seafile-deb/actions).

## Configuration

After installation, you'll need to configure a MySQL/MariaDB database, the secrets and a reverse proxy before starting the server with `systemctl start seafile.target`. For complete setup instructions, see the [Configuration Wiki](https://github.com/dionysius/seafile-deb/wiki/Configuration).

For advanced topics:

- [Admin Tools](https://github.com/dionysius/seafile-deb/wiki/Admin-Tools) - Garbage collection, integrity checks and admin accounts
- [Upgrading](https://github.com/dionysius/seafile-deb/wiki/Upgrading) - What happens automatically on a package upgrade
- [Migrating from Docker](https://github.com/dionysius/seafile-deb/wiki/Migrating-from-Docker) - Moving an existing docker deployment to the packages

See also the [Official Seafile Manual](https://manual.seafile.com/13.0/) for user guides and features.

## Issues

As this is an alternative installation method, there may be differences from the official docker images. **Please verify any problem is also reproducible with the official docker deployment before reporting upstream.**

- [Seafile forum](https://forum.seafile.com/) and [manual](https://manual.seafile.com/) — for issues with Seafile itself
- [Issues](https://github.com/dionysius/seafile-deb/issues) and [Discussions](https://github.com/dionysius/seafile-deb/discussions) — for issues with or related to these packages

## Security and stability

These packages favour the distribution-native way of running software. Wherever possible they link against system libraries and reuse distribution packages, so they receive the distribution's regular security updates and stability, with newer distributions or backports providing more recent versions.

By default the systemd services are extensively sandboxed, isolating the service from the rest of the system, while the configuration and data directories are restricted to the service's own user. Complex setups may need extra configuration, freely adjustable in the service file, whose comments and/or the [Wiki](https://github.com/dionysius/seafile-deb/wiki) should cover the common cases.

## Release schedule

This project aims to closely match the releases of upstream. The first release in each minor version series starts as a prerelease with a 3-day waiting period to allow upstream to fix oversights in new features or changes. Subsequent releases follow the same waiting period. After the waiting period has passed, all prereleases are automatically promoted to normal releases including new releases. Important releases may skip the waiting period.

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

There are many arguments to fine-tune the build (see `gbp buildpackage --help` and `dpkg-buildpackage --help`), notable options: `-b` (binary-only, no source files), `-us` (unsigned source package), `-uc` (unsigned .buildinfo and .changes file), `--git-export-dir=<somedir>` (before building the package export the source there), for example:

```bash
gbp buildpackage -b -us -uc
```

On successful build packages can now be found in the parent directory `ls ../*.deb`.

## Inspirations and Alternatives

- [Seafile manual: build from source](https://manual.seafile.com/13.0/develop/server/)
- [haiwen/seafile-docker build scripts](https://github.com/haiwen/seafile-docker/tree/master/build)
