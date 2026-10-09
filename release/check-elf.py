#!/usr/bin/env python3
"""Reject binaries that are not fully static Linux x86_64 ELF files."""

import struct
import sys
from pathlib import Path


def check(path):
    data = Path(path).read_bytes()
    if len(data) < 64 or data[:7] != b"\x7fELF\x02\x01\x01":
        raise ValueError("Expected a 64-bit little-endian ELF executable")
    kind, machine = struct.unpack_from("<HH", data, 16)
    if kind not in (2, 3) or machine != 62:
        raise ValueError("Expected an x86_64 executable")
    offset = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    if size < 56 or count == 0 or offset + size * count > len(data):
        raise ValueError("Invalid ELF program-header table")
    for index in range(count):
        header_type = struct.unpack_from("<I", data, offset + index * size)[0]
        if header_type in (2, 3):
            raise ValueError("Binary has a dynamic segment or an ELF interpreter")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 release/check-elf.py BINARY")
    try:
        check(sys.argv[1])
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
    print("Fully static Linux x86_64 ELF verified.")
