#!/usr/bin/env bash
# check-stelos-owner.sh
#
# Prints "owner" or "user" depending on whether the currently authenticated
# GitHub identity on this machine matches the StelOS repo owner.
#
# Detection order:
#   1. gh CLI, if installed and logged in: gh api user --jq .login
#   2. git credential helper fallback: attempts to read a stored credential
#      for github.com and checks the username portion.
# If neither yields an identity, prints "user" (fail safe / least privilege).

set -uo pipefail

OWNER_LOGIN="stelnetxcis-create"

detected_login=""

if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        detected_login="$(gh api user --jq .login 2>/dev/null || echo "")"
    fi
fi

if [[ -z "$detected_login" ]]; then
    # Fallback: ask git's credential helper for a stored github.com credential
    cred_output="$(printf 'protocol=https\nhost=github.com\n' | git credential fill 2>/dev/null || echo "")"
    detected_login="$(echo "$cred_output" | sed -n 's/^username=//p')"
fi

if [[ -n "$detected_login" && "$detected_login" == "$OWNER_LOGIN" ]]; then
    echo "owner"
else
    echo "user"
fi
