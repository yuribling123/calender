#!/bin/zsh
set -eu
cd "${0:A:h:h}"
check_dir=$(mktemp -d /tmp/moodcalendar-backup-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 - "$check_dir" <<'PY'
import json, sys, zipfile, warnings
from pathlib import Path
warnings.filterwarnings('ignore', message='Duplicate name:')
root = Path(sys.argv[1])
manifest = {'appIdentifier':'com.qingqing.MoodCalendar','appName':'Test','formatVersion':2,'exportedAt':'2026-10-20T00:00:00Z'}
old = {'dayKey':'2024-02-29','choiceID':4,'note':'old','photoPath':'photos/2024-02-29.jpg','updatedAt':'2024-03-01T00:00:00Z'}
new = dict(old, note='new', updatedAt='2024-03-02T00:00:00Z')
notes = [{'monthKey':'2024-02','text':'old month','updatedAt':old['updatedAt']}, {'monthKey':'2024-02','text':'new month','updatedAt':new['updatedAt']}]
payload = {'entries':[new,old],'monthlyNotes':notes,'monthlyNoteSkins':{'2024-02':'grid'}}
photo = b'\xff\xd8TEST\xff\xd9'
for name in ['legacy-duplicates.zip','conflicting-photos.zip','corrupt-crc.zip','invalid-date.zip']:
    data = dict(payload)
    if name == 'invalid-date.zip': data['entries'] = [dict(new,dayKey='2023-02-29'),old]
    with zipfile.ZipFile(root/name,'w',compression=zipfile.ZIP_STORED) as z:
        z.writestr('manifest.json',json.dumps(manifest))
        z.writestr('data.json',json.dumps(data))
        z.writestr('photos/2024-02-29.jpg',photo)
        z.writestr('photos/2024-02-29.jpg',photo if name != 'conflicting-photos.zip' else b'\xff\xd8OTHER\xff\xd9')
    if name == 'corrupt-crc.zip':
        content = (root/name).read_bytes().replace(photo,b'\xff\xd8FAIL\xff\xd9',1)
        (root/name).write_bytes(content)
PY
sources=(
    MoodCalendar/Domain/Mood.swift
    MoodCalendar/Domain/DayKey.swift
    MoodCalendar/Domain/DailyChoice.swift
    MoodCalendar/Domain/MonthLayout.swift
    MoodCalendar/Domain/MonthlyNoteSkin.swift
    MoodCalendar/Persistence/MoodEntry.swift
    MoodCalendar/Persistence/EntryStore.swift
    MoodCalendar/Persistence/MonthlyNoteSkinStore.swift
    Tests/DataBackupChecks.swift
)
xcrun --sdk macosx swiftc -parse-as-library $sources \
    MoodCalendar/Persistence/DataBackup.swift -o "$check_dir/checks"
"$check_dir/checks" "$check_dir" "$@"
# An optional pre-fix source verifies the normalized ZIP remains compatible with older builds.
if [[ -n "${LEGACY_BACKUP_SOURCE:-}" ]]; then
    xcrun --sdk macosx swiftc -parse-as-library -D LEGACY_IMPORT_CHECK $sources \
        "$LEGACY_BACKUP_SOURCE" -o "$check_dir/legacy-checks"
    "$check_dir/legacy-checks" "$check_dir" "$@"
fi
