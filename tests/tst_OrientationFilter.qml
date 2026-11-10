import QtQuick 2.0
import QtTest 1.0
import "../qml/OrientationFilter.js" as OrientationFilter

/*
 * When the shell turns. Samples are built from a turn in the screen plane
 * (0 = upright, positive = counter-clockwise, i.e. towards the left edge
 * being up) and a lean back from vertical (0 = upright, 90 = flat on its back).
 */
TestCase {
    name: "OrientationFilter"

    readonly property real g: 9.80665

    function sample(turn, lean) {
        var t = turn * Math.PI / 180, l = lean * Math.PI / 180
        var inPlane = g * Math.cos(l)
        return { x: -inPlane * Math.sin(t), y: inPlane * Math.cos(t), z: g * Math.sin(l) }
    }

    function next(turn, lean, current) {
        var s = sample(turn, lean)
        return OrientationFilter.orientationFor(s.x, s.y, s.z, current)
    }

    function test_angles_match_orientation_helper() {
        // Left edge up is 90, right edge up 270, as OrientationHelper uses them.
        compare(OrientationFilter.inPlaneAngle(-g, 0, 0), 90)
        compare(OrientationFilter.inPlaneAngle(g, 0, 0), 270)
        compare(OrientationFilter.inPlaneAngle(0, -g, 0), 180)
        compare(OrientationFilter.inPlaneAngle(0, g, 0), 0)
    }

    function test_small_turns_keep_portrait_data() {
        return [ { tag: "upright", lean: 0 }, { tag: "reading", lean: 50 }, { tag: "low", lean: 65 } ]
    }
    function test_small_turns_keep_portrait(data) {
        // sensorfw flipped here: at a 50 degree lean a 30 degree turn is
        // already past its thresholds.
        for (var turn = -55; turn <= 55; turn += 5)
            compare(next(turn, data.lean, 0), 0, "turn " + turn)
    }

    function test_turns_past_sixty_degrees() {
        compare(next(65, 40, 0), 90)
        compare(next(-65, 40, 0), 270)
        compare(next(90, 40, 0), 90)
    }

    function test_hysteresis_on_the_way_back() {
        // In landscape (90) it takes a turn back to within 30 of upright.
        compare(next(40, 30, 90), 90)
        compare(next(31, 30, 90), 90)
        compare(next(25, 30, 90), 0)
    }

    function test_upside_down() {
        compare(next(180, 20, 0), 180)
        compare(next(125, 20, 180), 180)
    }

    function test_flat_keeps_current() {
        compare(OrientationFilter.orientationFor(0, 0, g, 90), 90)
        // Lying almost flat, a turn says nothing.
        compare(next(90, 80, 0), 0)
    }

    function test_shaking_keeps_current() {
        var s = sample(90, 0)
        compare(OrientationFilter.orientationFor(s.x * 2, s.y * 2, s.z * 2, 0), 0)
        compare(OrientationFilter.orientationFor(s.x * 0.3, s.y * 0.3, s.z * 0.3, 0), 0)
    }
}
