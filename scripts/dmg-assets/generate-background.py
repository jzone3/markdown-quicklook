#!/usr/bin/env python3
"""Compatibility wrapper for the macOS-native DMG background generator."""

from __future__ import annotations

import os
import subprocess


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    subprocess.run([os.path.join(here, "generate-background.swift")], check=True)


if __name__ == "__main__":
    main()
