#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.mathieuares.outpost.savedState
store=/tmp/Outpost-self.json
rm -f $store ${store:r}.log
APP_STORE=$store ~/Applications/Outpost.app/Contents/MacOS/Outpost --selftest
