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
COMPONENTS=${COMPONENTS:-../../luneos-components}
QMLTESTRUNNER=${QMLTESTRUNNER:-$(command -v qmltestrunner \
    || ls /usr/lib/qt6/bin/qmltestrunner 2>/dev/null \
    || ls -d "$HOME"/Qt/6.*/gcc_64/bin/qmltestrunner 2>/dev/null | sort -V | tail -1)}

cd "$(dirname "$0")" || exit 1

if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "qmltestrunner not found; set QMLTESTRUNNER to your Qt's bin/qmltestrunner" >&2
    exit 1
fi

status=0
for t in tst_*.qml; do
    echo "--- $t"
    # ../qml so "import Utils 1.0" finds qml/Utils/qmldir, the same module the
    # shell itself imports.
    "$QMLTESTRUNNER" -input "$t" \
        -import ../qml \
        -import "$COMPONENTS/modules" \
        -import "$COMPONENTS/test/imports" "$@" || status=1
done

exit $status
