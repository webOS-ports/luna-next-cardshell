import QtQuick 2.0
import QtTest 1.0

import "../qml/Utils"
import "../qml/WindowManager"

/*
 * The gesture area's input (SwipeArea): a quick swipe is a swipe and nothing
 * else, and a tap is a tap. LunaGestureArea turns tapped() into tapGesture(),
 * which flips the current card between maximized and carded, so a swipe that
 * also counted as a tap would do both.
 *
 * An Item is the root, not the TestCase: with the TestCase as the root, no
 * mouse event reaches the area.
 */
Item {
    id: root
    width: 600; height: 200

    SwipeArea {
        id: area
        x: 0; y: 100
        width: 600; height: 100
    }

    // The shell's gesture area, which hands the tap on as tapGesture().
    LunaGestureArea {
        id: gestureArea
        x: 0; y: 0
        width: 600; height: 90
    }

    TestCase {
        name: "SwipeArea"
        when: windowShown

        SignalSpy { id: taps; target: area; signalName: "tapped" }
        SignalSpy { id: rights; target: area; signalName: "swipeRightGesture" }
        SignalSpy { id: lefts; target: area; signalName: "swipeLeftGesture" }
        SignalSpy { id: gestureTaps; target: gestureArea; signalName: "tapGesture" }
        SignalSpy { id: gestureRights; target: gestureArea; signalName: "swipeRightGesture" }

        function init() {
            taps.clear();
            rights.clear();
            lefts.clear();
            gestureTaps.clear();
            gestureRights.clear();
        }

        function quickSwipe(dx) {
            var x = 300, y = 50, steps = 6;
            mousePress(area, x, y);
            for (var i = 1; i <= steps; ++i)
                mouseMove(area, x + dx * i / steps, y, 10, Qt.LeftButton);
            mouseRelease(area, x + dx, y, Qt.LeftButton, Qt.NoModifier, 10);
        }

        function test_swipeRightIsNotATap() {
            quickSwipe(200);
            compare(rights.count, 1);
            compare(taps.count, 0);
        }

        function test_swipeLeftIsNotATap() {
            quickSwipe(-200);
            compare(lefts.count, 1);
            compare(taps.count, 0);
        }

        function test_gestureAreaTap() {
            mouseClick(gestureArea, 300, 45);
            compare(gestureTaps.count, 1);
        }

        function test_gestureAreaSwipeIsNoTap() {
            var x = 300, y = 45;
            mousePress(gestureArea, x, y);
            for (var i = 1; i <= 6; ++i)
                mouseMove(gestureArea, x + 200 * i / 6, y, 10, Qt.LeftButton);
            mouseRelease(gestureArea, x + 200, y, Qt.LeftButton, Qt.NoModifier, 10);
            compare(gestureRights.count, 1);
            compare(gestureTaps.count, 0);
        }

        function test_tapIsATap() {
            mouseClick(area, 300, 50);
            compare(taps.count, 1);
            compare(rights.count + lefts.count, 0);
        }
    }
}
