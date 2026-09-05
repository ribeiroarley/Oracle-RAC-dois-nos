#!/bin/bash
args=()
for arg in "$@"; do
    clean="${arg#\'}"
    clean="${clean%\'}"
    args+=("$clean")
done
exec /usr/bin/scp.orig -O -T "${args[@]}"
