#!/bin/bash
# Emit a third-party license inventory for the go modules used by the given module
# directories (run from the build tree, with the module cache populated).
set -e
echo "Third-party go modules bundled in the go components"
echo "==================================================="
echo
for d in "$@"; do
    ( cd "$d" && go list -m -f '{{if and .Dir (not .Main)}}{{.Path}}	{{.Version}}	{{.Dir}}{{end}}' all 2>/dev/null )
done | sort -u | while IFS=$'\t' read -r path ver dir; do
    [ -n "$path" ] || continue
    echo "$path $ver"
    lic=$(ls "$dir"/LICENSE* "$dir"/COPYING* "$dir"/LICENCE* 2>/dev/null | head -1)
    if [ -n "$lic" ]; then
        echo "    --- $(basename "$lic") ---"
        sed 's/^/    /' "$lic"
    fi
    echo
done
