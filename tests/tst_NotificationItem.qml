import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1

import "../qml/Notifications"

/*
 * A notification is one line of title and one of body, however long the text
 * it was given: nothing wraps it, so without a width it runs off the screen.
 * The text is an application's or a stranger's, never markup.
 */
Item {
    width: 320
    height: 480

    NotificationItem {
        id: item
        width: 320
        height: 60
        title: new Array(200).join("title ")
        body: new Array(200).join("body ")
    }

    // A group of three, its top layer being swiped: the tablet drop-down's
    // and the phone's layouts.
    Component {
        id: groupComponent
        NotificationItem {
            width: 320
            height: 60
            title: "top title"
            body: "top body"
            belowTitle: "under title"
            belowBody: "under body"
            count: 3
        }
    }

    TestCase {
        name: "NotificationItem"
        when: windowShown

        function textsOf(node) {
            var found = [];
            (function walk(n) {
                for (var i = 0; i < n.children.length; i++) {
                    var c = n.children[i];
                    if (c.hasOwnProperty("elide"))
                        found.push(c);
                    else
                        walk(c);
                }
            })(node);
            return found;
        }
        function find(node, text) {
            var t = textsOf(node);
            for (var i = 0; i < t.length; i++)
                if (t[i].text === text)
                    return t[i];
            return null;
        }
        // Shown and at least partly on screen: visible all the way up, and
        // inside every clipping item it is in.
        function shows(node, root) {
            for (var n = node; n && n !== root; n = n.parent)
                if (!n.visible || n.opacity === 0)
                    return false;
            for (n = node.parent; n && n !== root; n = n.parent) {
                if (!n.clip)
                    continue;
                var r = node.mapToItem(n, 0, 0);
                if (r.x + node.width <= 0 || r.x >= n.width)
                    return false;
            }
            return true;
        }

        // The top layer's text follows the swipe; the icon and the badge, the
        // base, stay; the toast under it shows only once the top one moves.
        function test_onlyTheTopLayerSlides() {
            var g = createTemporaryObject(groupComponent, item.parent);
            var top = find(g, "top title");
            var under = find(g, "under title");
            verify(top && under);
            var icon = null;
            for (var i = 0; i < g.children.length; i++)
                if (g.children[i].hasOwnProperty("fillMode"))
                    icon = g.children[i];
            verify(icon);
            var topX = top.mapToItem(g, 0, 0).x, iconX = icon.mapToItem(g, 0, 0).x;
            verify(!shows(under, g), "the layer under is hidden while the top one is in place");

            g.layerOffset = 120;
            wait(0);
            compare(top.mapToItem(g, 0, 0).x, topX + 120, "the top layer moved");
            compare(icon.mapToItem(g, 0, 0).x, iconX, "the icon did not");
            verify(shows(under, g), "the layer under shows");

            g.layerOffset = 0;
            wait(0);
            compare(top.mapToItem(g, 0, 0).x, topX);
            verify(!shows(under, g));
        }

        // A single toast has nothing under it: its text is never offset.
        function test_singleToastIsNotLayered() {
            var g = createTemporaryObject(groupComponent, item.parent, { count: 1 });
            var top = find(g, "top title");
            var topX = top.mapToItem(g, 0, 0).x;
            g.layerOffset = 120;
            wait(0);
            compare(top.mapToItem(g, 0, 0).x, topX);
            verify(!shows(find(g, "under title"), g));
        }

        // The title and the body, wherever the layout puts them.
        function texts() {
            var found = [];
            (function walk(node) {
                for (var i = 0; i < node.children.length; i++) {
                    var child = node.children[i];
                    if (child.hasOwnProperty("elide") && child.visible)
                        found.push(child);
                    else
                        walk(child);
                }
            })(item);
            return found;
        }

        function test_longTextStaysInside() {
            var t = texts();
            compare(t.length, 2);
            for (var i = 0; i < t.length; i++) {
                var right = t[i].mapToItem(item, t[i].width, 0).x;
                verify(right <= item.width, "ends at " + right);
                compare(t[i].elide, Text.ElideRight);
                verify(t[i].truncated, "the end of the text is elided");
            }
        }

        function test_textIsNotMarkup() {
            var t = texts();
            for (var i = 0; i < t.length; i++)
                compare(t[i].textFormat, Text.PlainText);
        }
    }
}
