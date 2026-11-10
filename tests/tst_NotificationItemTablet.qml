import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1

import "../qml/Notifications"

/*
 * A group in the tablet's drop-down, its top card being swiped: as Enyo's
 * dashboard did, the card and its text move, the icon stays, and the toast
 * under it shows only in the strip the card has moved off
 * (DashboardLayer.configureClipping clipped the layer under to the drag).
 *
 * Its own file because the profile is process-wide (see run-tests.sh), and
 * set before the item is made, which reads Settings.tabletUi once.
 */
Item {
    id: root
    width: 600
    height: 200

    Component {
        id: groupComponent
        NotificationItem {
            width: 500
            height: 52
            title: "top title"
            body: "top body"
            belowTitle: "under title"
            belowBody: "under body"
            count: 3
        }
    }

    TestCase {
        name: "NotificationItemTablet"
        when: windowShown

        function initTestCase() {
            verify(Settings.setProfile("tp"));
        }

        // Every Text with this text: the phone's layout has its own copy,
        // hidden here.
        function findAll(node, text, found) {
            found = found || [];
            for (var i = 0; i < node.children.length; i++) {
                var c = node.children[i];
                if (c.hasOwnProperty("elide") && c.text === text)
                    found.push(c);
                else
                    findAll(c, text, found);
            }
            return found;
        }
        function shown(g, text) {
            return findAll(g, text).filter(function (t) { return shows(t, g); });
        }
        // Visible all the way up, and inside every clipping item it is in.
        function shows(node, top) {
            for (var n = node; n && n !== top; n = n.parent)
                if (!n.visible)
                    return false;
            for (n = node.parent; n && n !== top; n = n.parent) {
                if (!n.clip)
                    continue;
                var r = node.mapToItem(n, 0, 0);
                if (r.x + node.width <= 0 || r.x >= n.width)
                    return false;
            }
            return true;
        }

        // Enyo's dashboards lit nothing when pressed: a tablet's neither.
        function test_aPressLightsNothing() {
            var g = createTemporaryObject(groupComponent, root);
            waitForRendering(g);
            var before = grabImage(g);
            for (var x of [20, 70, 300, 480]) {
                g.pressX = x;
                g.pressed = true;
                waitForRendering(g);
                var after = grabImage(g);
                verify(!g.iconLit && !g.textLit);
                for (var px = 2; px < 500; px += 9)
                    for (var py = 2; py < 52; py += 9)
                        compare(String(after.pixel(px, py)), String(before.pixel(px, py)), "at " + px + "," + py + " pressed at " + x);
                g.pressed = false;
            }
        }

        // Enyo's 48 px icon on a 52 px row, centred in its 50 px cell 6 px in.
        function test_theIconIsEnyosSizeInItsCell() {
            var g = createTemporaryObject(groupComponent, root);
            var icon = findChild(g, "notificationIcon");
            fuzzyCompare(icon.height, g.height * 48 / 52, 0.01);
            fuzzyCompare(icon.x + icon.width / 2, g.height * (6 + 25) / 52, 0.01);
        }

        function test_onlyTheTopCardSlides() {
            var g = createTemporaryObject(groupComponent, root);
            verify(g.tablet, "the tablet layout");
            var top = shown(g, "top title")[0];
            var topX = top.mapToItem(g, 0, 0).x;
            compare(shown(g, "under title").length, 0, "nothing under while the card is in place");

            // Moved less than the gap between the card's edge and its text:
            // the strip it uncovers has none of the text under it yet.
            g.layerOffset = 10;
            wait(0);
            compare(top.mapToItem(g, 0, 0).x, topX + 10);
            compare(shown(g, "under title").length, 0, "the text under is not reached yet");

            g.layerOffset = 200;
            wait(0);
            compare(top.mapToItem(g, 0, 0).x, topX + 200);
            var under = shown(g, "under title");
            compare(under.length, 1, "the text under shows in the strip");
            compare(under[0].mapToItem(g, 0, 0).x, topX, "where the top text was");
        }
    }
}
