import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import Utils 1.0

TestCase {
    name: "ScreenShape"

    /*
     * qmltestrunner parses its own arguments and will not pass --profile through,
     * so the profile is chosen here - which SettingsStub documents as the way a
     * test case does it. It has to happen before anything reads ScreenShape:
     * Settings' values are plain variables and ScreenShape binds them once, which
     * is right on device (the real Settings properties are CONSTANT) and means the
     * singleton must not be touched before this runs.
     */
    function initTestCase() {
        verify(Settings.setProfile("radon"))
    }

    /*
     * radon: 720x1600, notch "324 0 72 102" centred on 360, corner radius 75.
     * GridUnit 15 (derived from the 262 dpi the adaptation declares), so the bar's
     * content height - Units.gu(3) - is 45.
     *
     * Written out rather than taken from Units.gu(3), and that is not laziness:
     * UnitsStub does Qt.include("SettingsStub.js"), and a .pragma library include
     * gives it its OWN copy of the profile state, so Units keeps the desktop
     * gridUnit (10) no matter what Settings.setProfile() is told. A mock quirk
     * only - the real Units and Settings are both C++ reading one config - but it
     * means a test must not mix the two.
     */
    readonly property real contentH: 45

    function test_profile_is_radon() {
        compare(Settings.displayWidth, 720)
        compare(Settings.displayHeight, 1600)
        compare(Settings.gridUnit, 15)
        compare(Settings.dpi, 262)
        compare(ScreenShape.cutouts.length, 1)
        compare(ScreenShape.cornerRadii.length, 4)
        verify(ScreenShape.known)
        verify(ScreenShape.hasCutouts)
        verify(ScreenShape.hasRoundedCorners)
    }

    function test_bar_grows_to_clear_the_notch() {
        // 102px notch against a 54px bar -> the bar has to be 102.
        compare(ScreenShape.topBarHeight(contentH, 0), 102)
    }

    /*
     * The notch turned into each orientation. radon's panel is 720x1600 and its
     * notch is "324 0 72 102", centred on the top edge; a quarter turn should put
     * it against a side edge, and a half turn against the bottom.
     */
    function test_rect_follows_the_rotation() {
        function r(a) { return ScreenShape.rotateRect(ScreenShape.cutouts[0], a) }

        var p = r(0)
        compare([p.x, p.y, p.width, p.height], [324, 0, 72, 102])

        var l = r(90)                       // scene is 1600x720
        compare([l.x, l.y, l.width, l.height], [1498, 324, 102, 72])
        compare(l.x + l.width, 1600)        // against the right edge
        compare(l.y + l.height / 2, 360)    // still centred across the short axis

        var u = r(180)
        compare([u.x, u.y, u.width, u.height], [324, 1498, 72, 102])
        compare(u.y + u.height, 1600)       // against the bottom edge

        var rl = r(270)
        compare([rl.x, rl.y, rl.width, rl.height], [0, 324, 102, 72])
        compare(rl.x, 0)                    // against the left edge
    }

    function test_scene_dimensions_swap_on_a_quarter_turn() {
        compare([ScreenShape.sceneWidth(0), ScreenShape.sceneHeight(0)], [720, 1600])
        compare([ScreenShape.sceneWidth(90), ScreenShape.sceneHeight(90)], [1600, 720])
        compare([ScreenShape.sceneWidth(180), ScreenShape.sceneHeight(180)], [720, 1600])
        compare([ScreenShape.sceneWidth(270), ScreenShape.sceneHeight(270)], [1600, 720])
    }

    function test_bar_only_grows_where_the_notch_is_on_top() {
        compare(ScreenShape.topBarHeight(contentH, 0), 102)
        // Turned, the notch is against a side or the bottom, so a TOP bar does
        // not have to grow for it - but it still has corners to dodge.
        compare(ScreenShape.topBarHeight(contentH, 90), contentH)
        compare(ScreenShape.topBarHeight(contentH, 180), contentH)
        compare(ScreenShape.topBarHeight(contentH, 270), contentH)
    }

    function test_corners_are_inset_at_every_rotation() {
        // This is the bug the first cut shipped: at a quarter turn the insets
        // came back 0 and the indicators ran into the curve.
        var inkTop = 0 + contentH * 0.1     // bar does not grow when turned
        for (var i = 0; i < 4; i++) {
            var a = i * 90
            verify(ScreenShape.topLeftInset(inkTop, a) > 0)
            verify(ScreenShape.topRightInset(inkTop, a) > 0)
        }
    }

    function test_gesture_area_is_lifted_only_when_the_notch_is_at_the_bottom() {
        compare(ScreenShape.bottomInset(0), 0)
        compare(ScreenShape.bottomInset(90), 0)
        compare(ScreenShape.bottomInset(180), 102)   // the notch, exactly
        compare(ScreenShape.bottomInset(270), 0)
    }

    function test_angle_is_normalized() {
        compare(ScreenShape.normalizedAngle(-90), 270)
        compare(ScreenShape.normalizedAngle(450), 90)
        compare(ScreenShape.normalizedAngle(360), 0)
        compare(ScreenShape.bottomInset(-180), 102)
    }

    function test_corner_inset_is_the_chord_not_the_radius() {
        // Content bottom-aligned in a 102px bar starts at y=57.
        // r=75: inset = 75 - sqrt(75^2 - (75-57)^2) = 75 - sqrt(5625-324) = 2.19 -> 3
        var inset = ScreenShape.topLeftInset(102 - contentH, 0)   // contentTop = 57
        compare(inset, 3)
        compare(ScreenShape.topRightInset(102 - contentH, 0), 3)
        // Nowhere near the naive full-radius inset.
        verify(inset < 75 / 4)
    }

    function test_corner_inset_is_larger_when_content_sits_higher() {
        // Centred instead of bottom-aligned would start at y=28 and cost 17px.
        compare(ScreenShape.cornerInset(75, 28), 17)
        verify(ScreenShape.cornerInset(75, 28) > ScreenShape.cornerInset(75, 57))
        // Content starting below the curve entirely costs nothing.
        compare(ScreenShape.cornerInset(75, 75), 0)
        compare(ScreenShape.cornerInset(75, 200), 0)
        compare(ScreenShape.cornerInset(0, 0), 0)
    }

    function test_the_notch_is_an_obstacle_for_the_content_band() {
        var obs = ScreenShape.obstaclesInBand(102 - contentH, contentH, 0)
        compare(obs.length, 1)
        compare(obs[0].x, 324)
        compare(obs[0].width, 72)
    }

    function test_a_cutout_below_the_band_is_not_an_obstacle() {
        // A band well clear of the notch sees nothing.
        compare(ScreenShape.obstaclesInBand(300, 54, 0).length, 0)
    }

    function test_clock_is_moved_off_the_lens() {
        var obs = ScreenShape.obstaclesInBand(102 - contentH, contentH, 0)
        var clockW = 80
        var minX = 6
        var maxX = 600
        // Where it wants to be: centred on a 720 bar -> 320, straddling 324..396.
        var centred = (720 - clockW) / 2
        compare(centred, 320)
        var x = ScreenShape.shiftClear(centred, clockW, obs, minX, maxX)
        // It must no longer overlap the notch...
        verify(x >= 396 || x + clockW <= 324)
        // ...and it should pick the nearer side, which is left (324-80=244).
        compare(x, 244)
    }

    function test_clock_untouched_when_it_already_clears() {
        var obs = ScreenShape.obstaclesInBand(102 - contentH, contentH, 0)
        compare(ScreenShape.shiftClear(100, 80, obs, 0, 700), 100)
        compare(ScreenShape.shiftClear(420, 80, obs, 0, 700), 420)
    }

    function test_clock_takes_the_right_side_when_left_has_no_room() {
        var obs = [ { x: 100, width: 72 } ]
        // minX 90 leaves no room to the left of x=100 for an 80px item.
        compare(ScreenShape.shiftClear(95, 80, obs, 90, 700), 172)
    }

    function test_no_room_either_side_leaves_it_put() {
        var obs = [ { x: 0, width: 700 } ]
        ignoreWarning(/no room either side of the cutout/)
        compare(ScreenShape.shiftClear(10, 80, obs, 0, 700), 10)
    }
}
