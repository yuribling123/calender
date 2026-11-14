#!/bin/zsh
set -eu
cd "${0:A:h:h}"
check_dir=$(mktemp -d /tmp/moodcalendar-bookmark-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sources=(
    MoodCalendar/Domain/Mood.swift
    MoodCalendar/Domain/DayKey.swift
    MoodCalendar/Domain/DailyChoice.swift
    MoodCalendar/Domain/MonthLayout.swift
    MoodCalendar/Domain/MonthlyNoteSkin.swift
    MoodCalendar/Persistence/MoodEntry.swift
    MoodCalendar/Persistence/MonthlyNoteSkinStore.swift
    MoodCalendar/Persistence/StarredDayStore.swift
)
xcrun --sdk macosx swiftc -parse-as-library $sources Tests/StarredDayPersistenceChecks.swift -o "$check_dir/checks"
"$check_dir/checks" seed "$check_dir/records.store"
"$check_dir/checks" check "$check_dir/records.store"
"$check_dir/checks" reopen "$check_dir/records.store"
xcrun --sdk macosx swiftc -parse-as-library $sources Tests/StarredDayChecks.swift -o "$check_dir/legacy-checks"
"$check_dir/legacy-checks"
