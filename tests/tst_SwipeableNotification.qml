import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * Swiping a notification away (SwipeableNotification), with the mouse as the
 * finger: a slow drag past half the width, or a flick faster than 1000 px/s,
 * slides it out the way it went and asks for it to be removed; less than that
 * snaps it back.
 *
 * Both of the shell's uses: the phone's NotificationArea, which takes either
 * direction, and the tablet's NotificationAreaTablet, which sets
 * blockSwipesToLeft. Which way it slid out is read from the furthest contentX
 * reached, since contentX goes back to 0 once the slide-out stops.
 *
 * An Item is the root, not the TestCase: with the TestCase as the root, no
 * mouse or touch event reaches a Flickable.
 */
Item {
    id: root
    width: 600; height: 200

    TestCase {
        id: testCase
        name: "SwipeableNotification"
        when: windowShown

        property real minX: 0
        property real maxX: 0

        Component {
            id: contentComponent
            Rectangle { width: 300; height: 80; color: "grey" }
        }

        Component {
            id: swipeableComponent
            SwipeableNotification {
                x: 150; y: 60
                width: 300; height: 80
                notifComponent: contentComponent
            }
        }

        SignalSpy { id: removed; signalName: "requestDestruction" }

        property var item: null
        property var flickable: null

        Connections {
            target: testCase.flickable
            function onContentXChanged() {
                testCase.minX = Math.min(testCase.minX, testCase.flickable.contentX);
                testCase.maxX = Math.max(testCase.maxX, testCase.flickable.contentX);
            }
        }

        function create(tablet, layered) {
            item = createTemporaryObject(swipeableComponent, root, { blockSwipesToLeft: tablet, layered: !!layered });
            flickable = item.children[0];
            removed.target = item;
            removed.clear();
            minX = 0;
            maxX = 0;
            wait(50);
        }

        // dx > 0: the finger moves right. Slow enough not to flick, and still
        // at the end, so the release is not a flick either.
        function drag(dx) {
            var x = item.width / 2, y = item.height / 2, steps = 20;
            mousePress(item, x, y);
            for (var i = 1; i <= steps; ++i)
                mouseMove(item, x + dx * i / steps, y, 30, Qt.LeftButton);
            wait(300);
            mouseRelease(item, x + dx, y);
        }

        function flick(dx) {
            var x = item.width / 2, y = item.height / 2, steps = 5;
            mousePress(item, x, y);
            for (var i = 1; i <= steps; ++i)
                mouseMove(item, x + dx * i / steps, y, 10, Qt.LeftButton);
            mouseRelease(item, x + dx, y, Qt.LeftButton, Qt.NoModifier, 10);
        }

        function forms() {
            return [ { tag: "phone", tablet: false }, { tag: "tablet", tablet: true } ];
        }

        function test_dragRightPastHalf_data() { return forms(); }
        function test_dragRightPastHalf(data) {
            create(data.tablet);
            drag(200);
            tryCompare(removed, "count", 1, 2000);
            compare(minX, -item.width, "slid out to the right");
            compare(maxX, 0);
        }

        function test_dragLeftPastHalf_data() {
            return [ { tag: "phone", tablet: false, out: 1 },
                     { tag: "tablet", tablet: true, out: 0 } ];
        }
        function test_dragLeftPastHalf(data) {
            create(data.tablet);
            drag(-200);
            if (data.out) {
                tryCompare(removed, "count", 1, 2000);
                compare(maxX, item.width, "slid out to the left");
                compare(minX, 0, "never went right");
            } else {
                wait(800);
                compare(removed.count, 0, "the tablet blocks swipes to the left");
                compare(maxX, 0, "and does not move that way");
                compare(flickable.contentX, 0);
            }
        }

        function test_shortDragSnapsBack_data() { return forms(); }
        function test_shortDragSnapsBack(data) {
            create(data.tablet);
            drag(60);
            wait(800);
            compare(removed.count, 0);
            compare(flickable.contentX, 0, "back in place");
        }

        // Let go short of half the width, it slides back rather than jumping.
        function test_shortDragSlidesBack_data() { return forms(); }
        function test_shortDragSlidesBack(data) {
            create(data.tablet);
            var x = item.width / 2, y = item.height / 2;
            mousePress(item, x, y);
            for (var i = 1; i <= 20; ++i)
                mouseMove(item, x + 100 * i / 20, y, 30, Qt.LeftButton);
            wait(300);
            verify(flickable.contentX < -50, "dragged: " + flickable.contentX);
            var seen = [];
            var record = function () { seen.push(flickable.contentX); };
            flickable.contentXChanged.connect(record);
            mouseRelease(item, x + 100, y);
            wait(500);
            flickable.contentXChanged.disconnect(record);
            compare(flickable.contentX, 0, "back in place");
            // After the furthest point (it may drift on a little after the
            // release), on its way back to 0 rather than straight there.
            var furthest = seen.indexOf(Math.min.apply(null, seen));
            var back = seen.slice(furthest + 1).filter(function (v) { return v < -1; });
            verify(back.length >= 2, "slid back through " + JSON.stringify(seen.map(Math.round)));
            compare(removed.count, 0);
        }

        // Turned landscape and back: the entry grows and shrinks again, and
        // has to end up where it started. Sargo's widths (GridUnit 25) left it
        // 85 pixels to the right.
        function test_widenedAndNarrowedStaysCentred_data() { return forms(); }
        function test_widenedAndNarrowedStaysCentred(data) {
            create(data.tablet);
            item.width = 1055;
            wait(50);
            compare(flickable.contentX, 0);
            item.width = 2195;
            wait(50);
            item.width = 1055;
            wait(300);
            compare(flickable.contentX, 0, "back in place after turning back");
            compare(removed.count, 0);
        }

        // A group with layers under its top one: a drag moves the top layer
        // only. The entry stays where it is and is told how far the top layer
        // has gone (layerOffset, + to the right); let go past half, the top
        // layer goes, and the entry is asked to drop it as before.
        function test_layeredEntryStaysPut_data() { return forms(); }
        function test_layeredEntryStaysPut(data) {
            create(data.tablet, true);
            var content = item.notifItem;
            var before = content.mapToItem(root, 0, 0).x;
            var x = item.width / 2, y = item.height / 2;
            mousePress(item, x, y);
            for (var i = 1; i <= 20; ++i)
                mouseMove(item, x + 100 * i / 20, y, 30, Qt.LeftButton);
            wait(100);
            verify(item.layerOffset > 50, "the top layer moved right: " + item.layerOffset);
            compare(item.layerOffset, -flickable.contentX);
            compare(content.mapToItem(root, 0, 0).x, before, "the rest did not");
            mouseRelease(item, x + 100, y);
            wait(800);
            compare(item.layerOffset, 0, "back in place");
            drag(200);
            tryCompare(removed, "count", 1, 2000);
            compare(content.mapToItem(root, 0, 0).x, before, "nor while the top layer went");
        }

        // A layered entry, like Enyo's layers, goes right only: on a phone
        // too, which otherwise takes either direction.
        function test_layeredEntryDoesNotGoLeft() {
            create(false, true);
            drag(-200);
            wait(800);
            compare(removed.count, 0, "not swiped away to the left");
            compare(maxX, 0, "and does not move that way");
            compare(item.layerOffset, 0);
            flick(-150);
            wait(800);
            compare(removed.count, 0, "nor flicked away");
            compare(maxX, 0);
        }

        // One layer left: the whole entry moves, and nothing is offset.
        function test_unlayeredEntryMoves_data() { return forms(); }
        function test_unlayeredEntryMoves(data) {
            create(data.tablet, false);
            var content = item.notifItem;
            var before = content.mapToItem(root, 0, 0).x;
            var x = item.width / 2, y = item.height / 2;
            mousePress(item, x, y);
            for (var i = 1; i <= 20; ++i)
                mouseMove(item, x + 100 * i / 20, y, 30, Qt.LeftButton);
            wait(100);
            compare(item.layerOffset, 0);
            verify(content.mapToItem(root, 0, 0).x - before > 50, "moved with the finger");
            mouseRelease(item, x + 100, y);
            wait(800);
        }

        function test_flickRight_data() { return forms(); }
        function test_flickRight(data) {
            create(data.tablet);
            flick(150);
            tryCompare(removed, "count", 1, 2000);
            compare(minX, -item.width, "slid out to the right");
        }

        function test_flickLeft_data() {
            return [ { tag: "phone", tablet: false, out: 1 },
                     { tag: "tablet", tablet: true, out: 0 } ];
        }
        function test_flickLeft(data) {
            create(data.tablet);
            flick(-150);
            if (data.out) {
                tryCompare(removed, "count", 1, 2000);
                compare(maxX, item.width, "slid out to the left");
            } else {
                wait(800);
                compare(removed.count, 0);
                compare(maxX, 0);
            }
        }
    }
}
