#!/bin/sh
# Run the card shell on a development machine.
#
# The C++ plugins that need webOS system libraries (luna-service2 and friends)
# are not built here: luneos-components ships pure QML mocks for all of them
# under test/imports, which is what the qmlproject's importPaths point at.
# Only LuneOS.Components and QtQuick.Controls.LuneOS have to be built.
#
# Override COMPONENTS or QMLBIN if your checkout or Qt lives elsewhere.
COMPONENTS=${COMPONENTS:-../../luneos-components}
QMLBIN=${QMLBIN:-$(command -v qml || ls -d "$HOME"/Qt/6.*/gcc_64/bin/qml 2>/dev/null | sort -V | tail -1)}

cd "$(dirname "$0")/qml" || exit 1

if [ ! -x "$QMLBIN" ]; then
    echo "qml runtime not found; set QMLBIN to your Qt's bin/qml" >&2
    exit 1
fi

QT_QUICK_CONTROLS_STYLE=LuneOS \
    "$QMLBIN" -I "$COMPONENTS/modules" -I "$COMPONENTS/test/imports" mainDesktop.qml "$@"
