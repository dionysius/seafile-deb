#!/usr/bin/env python3
"""Emit a third-party license inventory of the npm packages the frontend bundle
is built from (run in the frontend directory, with node_modules installed)."""
import json
import os
import subprocess


def license_of(pkg):
    lic = pkg.get("license") or pkg.get("licenses") or "UNKNOWN"
    if isinstance(lic, dict):
        return lic.get("type", "UNKNOWN")
    if isinstance(lic, list):
        return " OR ".join(l.get("type", "UNKNOWN") if isinstance(l, dict) else str(l) for l in lic)
    return str(lic)


def homepage_of(pkg):
    home = pkg.get("homepage")
    if not home:
        repo = pkg.get("repository")
        home = repo.get("url") if isinstance(repo, dict) else repo
    return home or ""


def main():
    paths = subprocess.run(
        ["npm", "ls", "--omit=dev", "--all", "--parseable"],
        capture_output=True, text=True, check=False,
    ).stdout.split()
    rows = {}
    for path in paths[1:]:
        try:
            with open(os.path.join(path, "package.json")) as f:
                pkg = json.load(f)
        except (OSError, ValueError):
            continue
        if "name" in pkg:
            rows[(pkg["name"], pkg.get("version", ""))] = (license_of(pkg), homepage_of(pkg))
    print("Third-party npm packages bundled in the frontend")
    print("=" * 60)
    print()
    for name, version in sorted(rows, key=lambda k: (k[0].lower(), k[1])):
        lic, home = rows[(name, version)]
        print(f"{name} {version}")
        print(f"    License: {lic}")
        if home:
            print(f"    Homepage: {home}")
        print()


if __name__ == "__main__":
    main()
