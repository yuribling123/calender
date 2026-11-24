#!/bin/zsh
set -eu
cd "${0:A:h:h}"
check_dir=$(mktemp -d /tmp/moodcalendar-update-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun --sdk macosx swiftc -module-cache-path "$check_dir/cache" -parse-as-library \
    MoodCalendar/Domain/AppUpdate.swift Tests/AppUpdateChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
