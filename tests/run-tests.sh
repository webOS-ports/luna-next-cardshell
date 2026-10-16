#!/bin/sh
# Run the shell's QML tests on a development machine.
#
# Same idea as run-desktop.sh one level up: the C++ plugins are not built here,
# luneos-components ships QML mocks for them under test/imports, and that is what
# these run against. tests/stubs adds the few mocks those lack.
#
#   tst_*.qml           Qt Quick Test suites. Each file gets its own
#                       qmltestrunner because SettingsStub's profile is
#                       process-wide and the things under test bind it once -
#                       which is correct on device, where the real Settings
#                       properties are CONSTANT, and means one process can only
#                       ever be one device. tst_ScreenShape picks the radon
#                       profile; tst_ScreenShapeAbsent deliberately stays on the
#                       default, to pin down that a device with no declared panel
#                       shape behaves exactly as it did before there was such a
#                       thing. A JavaScript TypeError or ReferenceError anywhere in
#                       a run fails it, even when every test passes.
#   load smoke test     the whole shell (qml/mainDesktop.qml) runs for a few
#                       seconds and its warnings are compared with
#                       baseline/shell-load-warnings.txt. A warning that is not
#                       in the baseline fails; line numbers are left out so that
#                       unrelated edits do not.
#
# Arguments are passed on to every qmltestrunner (e.g. -functions, -v2).
#
# Environment:
#   COMPONENTS, QMLTESTRUNNER   where luneos-components and Qt are (see env.sh)
#   ONLY="tst_A tst_B smoke"    run just these
#   SMOKE_SECONDS               how long the shell runs in the smoke test (10)
#   UPDATE_BASELINE=1           write the smoke test's warnings as the baseline
#   TEST_BUILD_DIR              scratch space (tests/.build, ignored by git)
set -u

# shellcheck source=tests/env.sh
. "$(dirname "$0")/env.sh"

fail=0

js_errors() {
	grep -E 'TypeError|ReferenceError' "$1" || true
}

run_suite() {
	suite=$1
	shift
	name=$(basename "$suite" .qml)
	log="$BUILD/$name.log"
	echo "--- $name"
	# shellcheck disable=SC2086 # QTEST_IMPORT_ARGS is a list of words
	"$QT_BIN/qmltestrunner" -input "$suite" $QTEST_IMPORT_ARGS "$@" >"$log" 2>&1
	status=$?
	grep -E '^(FAIL!|XPASS)|Loc:|Actual|Expected|^Totals' "$log"
	errors=$(js_errors "$log")
	if [ -n "$errors" ]; then
		echo "JavaScript errors:"
		printf '%s\n' "$errors"
		status=1
	fi
	[ $status -eq 0 ] || { fail=1; echo "   (full log: $log)"; }
}

normalise_warnings() {
	sed -E -e "s|file://$ROOT/||g" -e 's/:[0-9]+(:[0-9]+)?:/:/g' \
	       -e 's/_QMLTYPE_[0-9]+//g' -e 's/\(0x[0-9a-f]+\)//g' "$1" |
		grep -iE 'warn|error|is not|unavailable|undefined|cannot|unable' |
		LC_ALL=C sort -u
}

run_smoke() {
	echo "--- shell load smoke test"
	log="$BUILD/shell-load.log"
	# shellcheck disable=SC2086
	(cd "$ROOT/qml" &&
		timeout "${SMOKE_SECONDS:-10}" "$QT_BIN/qml" $IMPORT_ARGS mainDesktop.qml) >"$log" 2>&1
	current="$BUILD/shell-load-warnings.txt"
	normalise_warnings "$log" >"$current"
	baseline="$TESTS/baseline/shell-load-warnings.txt"

	if [ "${UPDATE_BASELINE:-0}" = 1 ]; then
		cp "$current" "$baseline"
		echo "baseline written: $baseline"
		return
	fi

	new=$(LC_ALL=C comm -13 "$baseline" "$current")
	errors=$(js_errors "$log")
	if [ -n "$new" ] || [ -n "$errors" ]; then
		echo "New warnings on loading the shell:"
		printf '%s\n' "$new" "$errors" | grep -v '^$'
		echo "   (full log: $log)"
		fail=1
	else
		echo "no new warnings"
	fi
}

for t in "$TESTS"/tst_*.qml; do
	name=$(basename "$t" .qml)
	case " ${ONLY:-$name} " in *" $name "*) run_suite "$t" "$@" ;; esac
done
case " ${ONLY:-smoke} " in *" smoke "*) run_smoke ;; esac

exit $fail
