import QtQuick 2.0
import QtTest 1.0
import "../qml/StatusBar/SystemMenu"

/*
 * System menu rows in the menu's Flickable, driven by touch as on a phone.
 * A hold opens a Wi-Fi network's details, and once opened at the hold timer
 * a hold must not come out of a scroll: one that starts slowly, or after a
 * short rest. It counts when the hold timer fires with the finger still.
 */
Item {
    id: root
    width: 480
    height: 400

    property int holds: 0
    property int taps: 0

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height
        Column {
            id: column
            width: flick.width
            Repeater {
                model: 30
                MenuListEntry {
                    width: column.width
                    content: Text { text: "row " + index; height: 20 }
                    onHeld: root.holds++
                    onAction: root.taps++
                }
            }
        }
    }

    TestCase {
        name: "MenuListEntryScroll"
        when: windowShown

        function init() {
            flick.cancelFlick();
            flick.contentY = 0;
            root.holds = 0;
            root.taps = 0;
            wait(50);
        }

        function dragUp(t, fromY, steps, stepPx, stepMs) {
            for (var i = 1; i <= steps; ++i) {
                wait(stepMs);
                t.move(0, root, 200, fromY - i * stepPx).commit();
            }
            return fromY - steps * stepPx;
        }

        function test_flickScrolls() {
            var t = touchEvent(root);
            t.press(0, root, 200, 300).commit();
            var y = dragUp(t, 300, 12, 20, 16);
            t.release(0, root, 200, y).commit();
            tryVerify(function() { return !flick.moving; }, 3000);
            verify(flick.contentY > 50, "the list did not scroll: " + flick.contentY);
            compare(root.holds, 0);
            compare(root.taps, 0);
        }

        // A slow start: the finger creeps past the drag distance before the
        // hold timer, then scrolls. A scroll, not a hold.
        function test_slowStartScrollIsNotAHold() {
            var t = touchEvent(root);
            t.press(0, root, 200, 300).commit();
            var y = dragUp(t, 300, 40, 4, 25);
            compare(root.holds, 0, "a hold fired during the scroll");
            t.release(0, root, 200, y).commit();
            tryVerify(function() { return !flick.moving; }, 3000);
            verify(flick.contentY > 50, "the list did not scroll: " + flick.contentY);
            compare(root.holds, 0);
            compare(root.taps, 0);
        }

        // A short rest, then a scroll: no hold.
        function test_restThenDragScrollsAndIsNotAHold() {
            var t = touchEvent(root);
            t.press(0, root, 200, 300).commit();
            wait(400);
            var y = dragUp(t, 300, 20, 10, 30);
            t.release(0, root, 200, y).commit();
            tryVerify(function() { return !flick.moving; }, 3000);
            verify(flick.contentY > 50, "the list did not scroll: " + flick.contentY);
            compare(root.holds, 0, "a hold fired with the scroll");
            compare(root.taps, 0);
        }

        // Held still (a finger's few pixels of jitter): a hold while the
        // finger is still down, as in the Wi-Fi app, and not also a tap.
        function test_stillHoldIsAHoldBeforeRelease() {
            var t = touchEvent(root);
            t.press(0, root, 200, 300).commit();
            for (var i = 1; i <= 12; ++i) {
                wait(100);
                t.move(0, root, 200 + (i % 2) * 2, 300).commit();
            }
            compare(root.holds, 1, "the hold did not act while the finger was down");
            t.release(0, root, 200, 300).commit();
            compare(root.holds, 1);
            compare(root.taps, 0, "the hold also tapped the row");
            compare(flick.contentY, 0);
        }

        // The finger slid sideways past the drag distance (which the list
        // does not take, it only scrolls up and down) and then stayed: not a
        // hold, as a long press in the Wi-Fi app gives up once it is dragged.
        function test_slideThenStayIsNotAHold() {
            var t = touchEvent(root);
            t.press(0, root, 200, 300).commit();
            for (var i = 1; i <= 5; ++i) {
                wait(30);
                t.move(0, root, 200 + i * 8, 300).commit();
            }
            wait(1200);
            t.release(0, root, 240, 300).commit();
            compare(root.holds, 0, "a hold fired after the finger slid");
        }

        function test_tapIsATap() {
            var t = touchEvent(root);
            t.press(0, root, 200, 300).commit();
            wait(50);
            t.release(0, root, 200, 300).commit();
            compare(root.taps, 1);
            compare(root.holds, 0);
        }
    }
}
