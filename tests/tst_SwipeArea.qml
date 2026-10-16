/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0
import QtTest 1.2
import LunaNext.Common 0.1
import "../qml/Utils"

/*
 * SwipeArea against the rules of legacy's gesture recogniser
 * (libhidtouchpanel): decided on lift, by distance only, tap in the middle,
 * up only once the finger leaves the area, and the back bounce filter.
 */
Item {
    id: root
    width: 480
    height: 400

    // The gesture strip sits at the bottom, like LunaGestureArea; the space above
    // stands in for the screen, so a finger can leave the strip upwards.
    SwipeArea {
        id: area
        x: 0
        y: 300
        width: 480
        height: 40
    }

    SignalSpy { id: tapSpy; target: area; signalName: "tapped" }
    SignalSpy { id: upSpy; target: area; signalName: "swipeUpGesture" }
    SignalSpy { id: leftSpy; target: area; signalName: "swipeLeftGesture" }
    SignalSpy { id: rightSpy; target: area; signalName: "swipeRightGesture" }
    SignalSpy { id: cancelSpy; target: area; signalName: "swipeCanceled" }

    TestCase {
        name: "SwipeArea"
        when: windowShown

        function init() {
            tapSpy.clear(); upSpy.clear(); leftSpy.clear(); rightSpy.clear(); cancelSpy.clear();
            area._backRepeatArmed = false;
        }

        // Press at (x0,y0), move through the given points, release at the last.
        // Coordinates are in the area's own space.
        function drag(x0, y0, points, delayMs) {
            mousePress(area, x0, y0);
            for (var i = 0; i < points.length; i++)
                mouseMove(area, points[i][0], points[i][1], delayMs === undefined ? 5 : delayMs);
            var last = points.length ? points[points.length - 1] : [x0, y0];
            mouseRelease(area, last[0], last[1]);
        }

        function counts() {
            return [tapSpy.count, upSpy.count, leftSpy.count, rightSpy.count, cancelSpy.count].join(",");
        }

        function test_tapInMiddle() {
            drag(240, 20, []);
            compare(counts(), "1,0,0,0,0");
        }

        function test_tapWithinRadiusStillTap() {
            var r = area.tapRadius - 1;
            drag(240, 20, [[240 + r * 0.7, 20 + r * 0.7]]);
            compare(counts(), "1,0,0,0,0");
        }

        function test_longStillTouchIsTap() {
            // No time limit on a tap, unlike Qt's press-and-hold.
            mousePress(area, 240, 20);
            wait(1200);
            mouseRelease(area, 240, 20);
            compare(counts(), "1,0,0,0,0");
        }

        function test_tapOutsideMiddleIgnored() {
            drag(20, 20, []);
            drag(460, 20, []);
            compare(counts(), "0,0,0,0,0");
        }

        function test_movedBeyondRadiusIsNotTap() {
            var d = area.tapRadius + 2;
            drag(240, 20, [[240 + d, 20]]);
            compare(tapSpy.count, 0);
            compare(cancelSpy.count, 1);
        }

        function test_slowShortBack() {
            // 40 legacy px slowly: no velocity test, so it counts.
            var x1 = 400 - area.strokeLength - 2;
            drag(400, 20, [[380, 20], [x1, 20]], 200);
            compare(counts(), "0,0,1,0,0");
        }

        function test_belowStrokeIsCancel() {
            var x1 = 400 - area.strokeLength + 2;
            drag(400, 20, [[x1, 20]]);
            compare(counts(), "0,0,0,0,1");
        }

        function test_forward() {
            drag(80, 20, [[80 + area.strokeLength + 2, 20]]);
            compare(counts(), "0,0,0,1,0");
        }

        function test_upMustLeaveTheArea() {
            // Up, but released inside the strip: not an up swipe.
            drag(240, 38, [[240, 2]]);
            compare(upSpy.count, 0);
            // Released just short of the margin above the strip.
            drag(240, 38, [[240, -area.launcherMargin + 2]]);
            compare(upSpy.count, 0);
            drag(240, 38, [[240, -area.launcherMargin - 2]]);
            compare(upSpy.count, 1);
        }

        function test_upWinsOverSideways() {
            // Released above the strip after drifting sideways: up is checked first.
            drag(300, 20, [[200, 0], [200, -area.launcherMargin - 5]]);
            compare(counts(), "0,1,0,0,0");
        }

        function test_backBounceDropped() {
            // A back that ends in the middle, then another starting there within 1 s.
            var mid = 240;
            drag(mid + 60, 20, [[mid, 20]]);
            compare(leftSpy.count, 1);
            drag(mid + 10, 20, [[mid - 50, 20]]);
            compare(leftSpy.count, 1);
            // The bounce disarmed the filter: a third back goes through.
            drag(mid + 10, 20, [[mid - 50, 20]]);
            compare(leftSpy.count, 2);
        }

        function test_backAfterWindowNotDropped() {
            var mid = 240;
            drag(mid + 60, 20, [[mid, 20]]);
            wait(area.backRepeatWindowMs + 100);
            drag(mid + 10, 20, [[mid - 50, 20]]);
            compare(leftSpy.count, 2);
        }

        function test_backEndingAtSideDoesNotArm() {
            drag(150, 20, [[20, 20]]);
            drag(240, 20, [[240 - area.strokeLength - 5, 20]]);
            compare(leftSpy.count, 2);
        }

        function test_longCrossingBackSkipsBounceFilter() {
            var mid = 240;
            drag(mid + 60, 20, [[mid, 20]]);   // arms the filter
            // Starts in the middle band, but is a long swipe across the middle.
            drag(area.width * area.homeZoneRight + 5, 20,
                 [[area.width * area.homeZoneLeft - area.longStrokeLength, 20]]);
            compare(leftSpy.count, 2);
        }
    }
}
