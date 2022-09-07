#!/usr/bin/env python3

import argparse

supported_games = [
    "quake",
    "descent2",
    "rtcw"
]

parser = argparse.ArgumentParser(description="Installer script for games on chromebooks.")

parser.add_argument("-i", "--install", metavar="INSTALLER", choices=supported_games, help="install the game file onto your system.")

parser.parse_args()
parser.print_help()
