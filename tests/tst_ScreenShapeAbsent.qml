import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import Utils 1.0

/*
 * Every device that declares no panel shape - which is all of them but radon -
 * must behave exactly as it did before ScreenShape existed. Own file because
 * Settings' profile is process-wide and ScreenShape binds it once.
 */
TestCase {
    name: "ScreenShapeAbsent"

    function test_nothing_is_known() {
        compare(ScreenShape.cutouts.length, 0)
        compare(ScreenShape.cornerRadii.length, 0)
        verify(!ScreenShape.known)
        verify(!ScreenShape.hasCutouts)
        verify(!ScreenShape.hasRoundedCorners)
    }

    function test_bar_keeps_its_height() {
        compare(ScreenShape.topBarHeight(54, 0), 54)
        compare(ScreenShape.topBarHeight(54, 90), 54)
        compare(ScreenShape.topBarHeight(30, 0), 30)
    }

    function test_no_insets() {
        compare(ScreenShape.topLeftInset(0, 0), 0)
        compare(ScreenShape.topRightInset(0, 0), 0)
        compare(ScreenShape.topLeftInset(48, 0), 0)
    }

    function test_no_obstacles_so_the_clock_stays_centred() {
        var obs = ScreenShape.obstaclesInBand(0, 54, 0)
        compare(obs.length, 0)
        // shiftClear with no obstacles is the identity, so the existing centring
        // and indicator clamp are all that act on the clock.
        compare(ScreenShape.shiftClear(320, 80, obs, 0, 700), 320)
    }
}
