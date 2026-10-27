#!/bin/sh
# Run the shell's QML unit tests on a development machine.
#
# Same idea as run-desktop.sh one level up: the C++ plugins are not built here,
# luneos-components ships QML mocks for them under test/imports, and that is what
# these run against.
#
# Each test file gets its own qmltestrunner because SettingsStub's profile is
# process-wide and the things under test bind it once - which is correct on device,
# where the real Settings properties are CONSTANT, and means one process can only
# ever be one device. tst_ScreenShape picks the radon profile; tst_ScreenShapeAbsent
# deliberately stays on the default, to pin down that a device with no declared
# panel shape behaves exactly as it did before there was such a thing.
#
# Override COMPONENTS or QMLTESTRUNNER if your checkout or Qt lives elsewhere.
#
# A Qt 6 qmltestrunner is looked for before the one on PATH: on Debian and
# Ubuntu that one is often qtchooser's wrapper, which runs Qt 5's.
COMPONENTS=${COMPONENTS:-../../luneos-components}
if [ -z "${QMLTESTRUNNER:-}" ]; then
    for candidate in /usr/lib/qt6/bin/qmltestrunner \
            $(ls -d "$HOME"/Qt/6.*/gcc_64/bin/qmltestrunner 2>/dev/null | sort -V | tail -1) \
            "$(command -v qmltestrunner)"; do
        if [ -x "$candidate" ]; then
            QMLTESTRUNNER=$candidate
            break
        fi
    done
fi

cd "$(dirname "$0")" || exit 1

if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "qmltestrunner not found; set QMLTESTRUNNER to your Qt's bin/qmltestrunner" >&2
    exit 1
fi

# As on the device, where luna-surfacemanager's launcher exports it: HardwareKeys
# reads its per-device override with a file:// XMLHttpRequest, which Qt refuses
# without this, and tst_HardwareKeys feeds it the override files in data/.
export QML_XHR_ALLOW_FILE_READ=1

status=0
for t in tst_*.qml; do
    echo "--- $t"
    # ../qml so "import Utils 1.0" finds qml/Utils/qmldir, the same module the
    # shell itself imports.
    "$QMLTESTRUNNER" -input "$t" \
        -import ../qml \
        -import imports \
        -import "$COMPONENTS/modules" \
        -import "$COMPONENTS/test/imports" "$@" || status=1
done

exit $status
