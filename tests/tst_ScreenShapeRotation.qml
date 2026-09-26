import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import Utils 1.0

/*
 * Rotation, on a panel whose corners and cutout are all different.
 *
 * radon cannot pin this down: its four radii are all 75 and its notch is
 * symmetric about the centre of the top edge, so a corner mapping that is
 * rotated the wrong way, or a rect transform mirrored in the wrong axis, gives
 * the same answer as the correct one. Here every value differs.
 *
 * Own file because Settings' profile is process-wide and ScreenShape binds it
 * once - which is right on device, where the real properties are CONSTANT.
 */
TestCase {
    name: "ScreenShapeRotation"

    function initTestCase() {
        verify(Settings.setProfile("asymmetric"))
    }

    function test_profile() {
        compare([Settings.displayWidth, Settings.displayHeight], [400, 800])
        compare(ScreenShape.cornerRadii, [10, 20, 30, 40])
        compare(ScreenShape.cutouts.length, 1)
    }

    /*
     * A 40x60 cutout in the panel's TOP-LEFT corner. Turned, it must stay in a
     * corner and stay the same size, swapping w/h on the quarter turns.
     *
     *   a=90  panel left edge becomes the top   -> top-right of the scene
     *   a=180 everything reflects               -> bottom-right
     *   a=270 panel right edge becomes the top  -> bottom-left
     */
    function test_corner_cutout_walks_the_corners() {
        function r(a) { return ScreenShape.rotateRect(ScreenShape.cutouts[0], a) }

        var a0 = r(0)
        compare([a0.x, a0.y, a0.width, a0.height], [0, 0, 40, 60])      // top-left

        var a90 = r(90)                                                  // scene 800x400
        compare([a90.x, a90.y, a90.width, a90.height], [740, 0, 60, 40])
        compare(a90.x + a90.width, ScreenShape.sceneWidth(90))           // hard right
        compare(a90.y, 0)                                                // and top

        var a180 = r(180)                                                // scene 400x800
        compare([a180.x, a180.y, a180.width, a180.height], [360, 740, 40, 60])
        compare(a180.x + a180.width, ScreenShape.sceneWidth(180))
        compare(a180.y + a180.height, ScreenShape.sceneHeight(180))      // bottom-right

        var a270 = r(270)                                                // scene 800x400
        compare([a270.x, a270.y, a270.width, a270.height], [0, 360, 60, 40])
        compare(a270.x, 0)
        compare(a270.y + a270.height, ScreenShape.sceneHeight(270))      // bottom-left
    }

    /* Corner i of the scene was corner (i - angle/90) of the panel. */
    function test_radii_walk_with_the_rotation() {
        // panel TL,TR,BR,BL = 10,20,30,40
        compare([ScreenShape.radiusAt(0, 0), ScreenShape.radiusAt(1, 0)], [10, 20])
        compare([ScreenShape.radiusAt(0, 90), ScreenShape.radiusAt(1, 90)], [40, 10])
        compare([ScreenShape.radiusAt(0, 180), ScreenShape.radiusAt(1, 180)], [30, 40])
        compare([ScreenShape.radiusAt(0, 270), ScreenShape.radiusAt(1, 270)], [20, 30])
    }

    /* The cutout is against the top edge at 0 and 90, so only those grow a top
     * bar; it reaches the bottom edge at 180 and 270, so only those lift a
     * bottom one. The two must never both fire for one cutout. */
    function test_top_and_bottom_never_both_fire() {
        for (var i = 0; i < 4; i++) {
            var a = i * 90
            var grew = ScreenShape.topBarHeight(20, a) > 20
            var lifted = ScreenShape.bottomInset(a) > 0
            verify(!(grew && lifted))
        }
        compare(ScreenShape.topBarHeight(20, 0), 60)     // 60px deep at the top
        compare(ScreenShape.topBarHeight(20, 90), 40)    // 40px deep once turned
        compare(ScreenShape.bottomInset(180), 60)
        compare(ScreenShape.bottomInset(270), 40)
        compare(ScreenShape.bottomInset(0), 0)
        compare(ScreenShape.bottomInset(90), 0)
    }
}
