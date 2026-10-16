#!/bin/sh
# Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# static-analysis.sh
#
# Static-analysis gate for the card shell. The shell is QML and JavaScript
# only, so the C/C++ tools (-fanalyzer, clang --analyze, clang-tidy, cppcheck,
# flawfinder, sparse, sanitizers, valgrind) have nothing to look at here.
# What does apply:
#
#   qmllint      unresolved types and properties, unqualified access, missing
#                imports, bad signal handlers, deprecated syntax - every .qml
#                under qml/, against the same stubs the tests run with.
#                The tree has many findings from before this gate existed, so
#                only new ones fail: they are compared with
#                tests/baseline/qmllint.txt, without line numbers so that
#                unrelated edits do not.
#   ShellCheck   the test scripts themselves.
#
# Environment: as for run-tests.sh (COMPONENTS, QMLTESTRUNNER, TEST_BUILD_DIR).
#   UPDATE_BASELINE=1   write qmllint's findings as the new baseline
#
# A tool that is not installed is reported and skipped, not passed.
set -u

# shellcheck source=tests/env.sh
. "$(dirname "$0")/env.sh"

fail=0

echo "== qmllint"
current="$BUILD/qmllint.txt"
: >"$current"
# shellcheck disable=SC2086 # IMPORT_ARGS is a list of words
find "$ROOT/qml" -name '*.qml' | LC_ALL=C sort | while read -r f; do
	rel=${f#"$ROOT"/}
	"$QT_BIN/qmllint" $IMPORT_ARGS "$f" 2>&1 |
		grep -E '^(Warning|Critical|Error):' |
		sed -E -e "s|$ROOT/||g" -e "s|^[A-Za-z]+: ($rel:)?||" \
		       -e 's/^[0-9]+:[0-9]+: //' -e "s|^|$rel: |"
done | LC_ALL=C sort >"$current"

baseline="$TESTS/baseline/qmllint.txt"
if [ "${UPDATE_BASELINE:-0}" = 1 ]; then
	cp "$current" "$baseline"
	echo "baseline written: $baseline ($(wc -l <"$baseline") findings)"
else
	# comm counts repeated lines, so one more of an existing finding is new too
	new=$(LC_ALL=C comm -13 "$baseline" "$current")
	if [ -n "$new" ]; then
		echo "New findings:"
		printf '%s\n' "$new"
		fail=1
	else
		echo "no new findings ($(wc -l <"$current") in the baseline's files, $(LC_ALL=C comm -23 "$baseline" "$current" | wc -l) fixed)"
	fi
fi

echo "== shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
	if shellcheck -x -s sh "$TESTS"/*.sh; then
		echo "clean"
	else
		fail=1
	fi
else
	echo "not installed, skipped"
fi

exit $fail
