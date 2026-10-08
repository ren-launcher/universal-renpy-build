#!/usr/bin/env bash
#
# check-16k-alignment.sh — verify Android .so files are 16 KB page aligned.
#
# Google Play requires that every PT_LOAD segment of every bundled native
# library has p_align >= 0x4000 (16384) on 16 KB page-size devices.
#
# Linking with only `-Wl,-z,max-page-size=16384` is NOT enough on older
# toolchains: the first PT_LOAD is aligned to max-page-size, but the remaining
# segments stay at the default common-page-size (0x1000). Both are required:
#
#     -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
#
# Usage:
#   scripts/check-16k-alignment.sh <path> [<path> ...]
#
#   Each <path> may be a shared object, or a directory, in which case every
#   *.so below it is checked.
#
# Environment:
#   READELF   readelf-compatible binary (default: readelf). For the NDK, e.g.
#             $ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf
#
# Exit status:
#   0  every PT_LOAD segment of every checked file is aligned to >= 0x4000
#   1  at least one segment is under-aligned
#   2  usage or tooling error

set -u

READELF="${READELF:-readelf}"
MIN_ALIGN=$((0x4000))

if ! command -v "$READELF" >/dev/null 2>&1; then
    echo "ERROR: readelf tool '$READELF' not found." >&2
    echo "       Set READELF=/path/to/llvm-readelf (bundled with the NDK)." >&2
    exit 2
fi

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <path> [<path> ...]" >&2
    exit 2
fi

# Collect the list of .so files to inspect.
files=()
for arg in "$@"; do
    if [ -d "$arg" ]; then
        while IFS= read -r f; do
            files+=("$f")
        done < <(find "$arg" -type f -name '*.so' | sort)
    elif [ -f "$arg" ]; then
        files+=("$arg")
    else
        echo "WARNING: '$arg' does not exist, skipping" >&2
    fi
done

if [ "${#files[@]}" -eq 0 ]; then
    echo "ERROR: no .so files found to check" >&2
    exit 2
fi

fail=0
for so in "${files[@]}"; do
    # Each LOAD program-header line ends with the Align column, e.g. "0x4000".
    bad=""
    while IFS= read -r align; do
        [ -z "$align" ] && continue
        # Only compare well-formed hex alignments.
        [[ "$align" =~ ^0x[0-9a-fA-F]+$ ]] || continue
        if [ "$((align))" -lt "$MIN_ALIGN" ]; then
            bad="$bad $align"
        fi
    done < <("$READELF" -lW "$so" 2>/dev/null | awk '$1 == "LOAD" { print $NF }')

    if [ -n "$bad" ]; then
        echo "FAIL: $so has PT_LOAD segment(s) below 0x4000:$bad"
        fail=1
    else
        echo "OK:   $so"
    fi
done

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "16 KB page alignment check FAILED."
    exit 1
fi

echo ""
echo "All ${#files[@]} checked librar(ies) are 16 KB page aligned."
