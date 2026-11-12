import QtQuick 2.0
import QtTest 1.0

import "../qml"

/*
 * The turn waits for the second frame after the angle changes, so the
 * relayout is drawn before anything moves. On a square screen (the Titan's
 * 1440x1440) a turn changes no size, nothing redraws, and that frame only
 * came with the next unrelated repaint: every turn started from the 500 ms
 * fallback. The helper now asks for the frames it waits for.
 */
TestCase {
    name: "OrientationSquareTurn"
    when: windowShown

    Item {
        id: screen
        width: 400
        height: 400

        OrientationHelper { id: helper }
    }

    property double changedAt: 0
    property double movedAt: 0

    Connections {
        target: helper
        function onOrientationAngleChanged() { changedAt = Date.now(); movedAt = 0; }
        function onVisualAngleChanged() { if (movedAt === 0) movedAt = Date.now(); }
    }

    function sensor() {
        for (var i = 0; i < helper.data.length; ++i) {
            var child = helper.data[i];
            if (child && typeof child.sample === "function" && child.settleInterval !== undefined)
                return child;
        }
        return null;
    }

    function hold(angle) {
        var g = 9.80665;
        var s = sensor();
        if (angle === 0) s.sample(0, g, 0);
        else if (angle === 90) s.sample(-g, 0, 0);
        else if (angle === 180) s.sample(0, -g, 0);
        else s.sample(g, 0, 0);
        tryCompare(s, "angle", angle);
    }

    function turnTo(angle) {
        hold(angle);
        tryCompare(helper, "visualAngle", angle, 2000);
        verify(movedAt > 0, "the screen turned");
        return movedAt - changedAt;
    }

    function test_a_turn_on_a_square_screen_starts_at_once() {
        compare(helper.width, helper.height);
        // Let the first frames go by, so nothing else is redrawing.
        wait(300);
        var first = turnTo(90);
        wait(300);
        var back = turnTo(0);
        verify(first < 250, "turn to 90 started after " + first + " ms");
        verify(back < 250, "turn back started after " + back + " ms");
    }
}
