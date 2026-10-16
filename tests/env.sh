# Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# env.sh - sourced by run-tests.sh and static-analysis.sh.
#
# Finds Qt and luneos-components and builds the import paths the shell needs
# on a development machine. Override COMPONENTS or QMLTESTRUNNER if your
# checkout or Qt lives elsewhere; qml and qmllint are taken from the same
# directory as qmltestrunner.
#
# Sets ROOT, TESTS, BUILD, QT_BIN, IMPORTS, IMPORT_ARGS and QTEST_IMPORT_ARGS.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TESTS="$ROOT/tests"
BUILD="${TEST_BUILD_DIR:-$TESTS/.build}"
COMPONENTS=$(cd "${COMPONENTS:-$ROOT/../luneos-components}" 2>/dev/null && pwd)

# A candidate only counts if its qml actually runs: /usr/bin often has
# qtchooser's wrappers, which exist but point at no Qt at all.
qt_works() {
	[ -x "$1/qmltestrunner" ] && [ -x "$1/qmllint" ] && "$1/qml" --version >/dev/null 2>&1
}
if [ -n "${QMLTESTRUNNER:-}" ]; then
	QT_BIN=$(dirname "$QMLTESTRUNNER")
else
	for candidate in $(command -v qmltestrunner >/dev/null 2>&1 && dirname "$(command -v qmltestrunner)") \
			/usr/lib/qt6/bin \
			$(find "$HOME/Qt" -mindepth 3 -maxdepth 3 -type d -path '*/gcc_64/bin' 2>/dev/null | sort -rV); do
		if qt_works "$candidate"; then
			QT_BIN=$candidate
			break
		fi
	done
fi
if [ -z "${QT_BIN:-}" ] || ! qt_works "$QT_BIN"; then
	echo "No working Qt (qml, qmltestrunner, qmllint) found; set QMLTESTRUNNER to your Qt's bin/qmltestrunner" >&2
	exit 2
fi
if [ -z "$COMPONENTS" ] || [ ! -d "$COMPONENTS/test/imports" ]; then
	echo "No luneos-components checkout found; set COMPONENTS" >&2
	exit 2
fi

# The stubs, plus what they lack. Later import paths win, so the copy
# extended here shadows luneos-components' own module.
IMPORTS="$BUILD/imports"
rm -rf "$IMPORTS"
mkdir -p "$IMPORTS"
cp -r "$COMPONENTS/test/imports/WebOSCoreCompositor" "$IMPORTS/"
cp "$TESTS/stubs/KeyFilter.qml" "$IMPORTS/WebOSCoreCompositor/"
grep -q '^KeyFilter ' "$IMPORTS/WebOSCoreCompositor/qmldir" ||
	echo "KeyFilter 1.0 KeyFilter.qml" >> "$IMPORTS/WebOSCoreCompositor/qmldir"
cp -r "$TESTS/stubs/WebOSServices" "$IMPORTS/"

export QT_QPA_PLATFORM=offscreen
export QT_QUICK_CONTROLS_STYLE=LuneOS

# Used by the scripts that source this. ../qml first, so "import Utils 1.0"
# finds qml/Utils/qmldir, the same module the shell itself imports.
# shellcheck disable=SC2034
IMPORT_ARGS="-I $ROOT/qml -I $COMPONENTS/modules -I $COMPONENTS/test/imports -I $IMPORTS"
# shellcheck disable=SC2034
QTEST_IMPORT_ARGS="-import $ROOT/qml -import $COMPONENTS/modules -import $COMPONENTS/test/imports -import $IMPORTS"
