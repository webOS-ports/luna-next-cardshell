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

        // White text pixels in the text's own area, as drawn: what the
        // user sees, stacking included. A single toast's bar is the whole
        // entry, and over its text it hid every word.
        function whitePixelsOfText(g) {
            var top = find(g, "top title");
            var img = grabImage(g);
            var x0 = Math.ceil(top.mapToItem(g, 0, 0).x);
            var white = 0;
            for (var y = 0; y < g.height; y += 1)
                for (var x = x0; x < g.width; x += 2) {
                    var c = img.pixel(x, y);
                    if (c.r > 0.85 && c.g > 0.85 && c.b > 0.85)
                        ++white;
                }
            return white;
        }
        function test_singleToastTextIsDrawn() {
            var g = createTemporaryObject(groupComponent, item.parent, { count: 1 });
            waitForRendering(g);
            verify(whitePixelsOfText(g) > 20, "the text shows over its bar");
        }
        function test_groupTopTextIsDrawn() {
            var g = createTemporaryObject(groupComponent, item.parent, { count: 3 });
            waitForRendering(g);
            verify(whitePixelsOfText(g) > 20, "the text shows over its bar");
        }

        // A press lights what Mojo lit: the half touched, or a single
        // notification's whole entry; drawn, so the stacking counts.
        function grey(g, x, y) {
            return grabImage(g).pixel(x, y).r;
        }
        function pressed(count, x) {
            var g = createTemporaryObject(groupComponent, item.parent, { count: count });
            g.pressX = x;
            g.pressed = true;
            waitForRendering(g);
            return g;
        }
        // Inside each pill, clear of the icon and the text.
        readonly property int iconPillX: 4
        readonly property int textPillX: 314
        readonly property real lit: 0x50 / 255
        function test_pressOnTheTextLightsTheTextPillOnly() {
            var g = pressed(3, 200);
            verify(grey(g, textPillX, 30) > lit, "text pill lit");
            verify(grey(g, iconPillX, 30) < lit, "icon pill not");
            verify(g.textLit && !g.iconLit);
        }
        function test_pressOnTheIconLightsTheIconPillOnly() {
            var g = pressed(3, 20);
            verify(grey(g, iconPillX, 30) > lit, "icon pill lit");
            verify(grey(g, textPillX, 30) < lit, "text pill not");
            verify(g.iconLit && !g.textLit);
        }
        function test_pressOnASingleLightsTheEntry() {
            var g = pressed(1, 200);
            verify(grey(g, iconPillX, 30) > lit);
            verify(grey(g, textPillX, 30) > lit);
        }
        function test_nothingLitUnpressed() {
            var g = createTemporaryObject(groupComponent, item.parent, { count: 3 });
            waitForRendering(g);
            verify(grey(g, iconPillX, 30) < lit);
            verify(grey(g, textPillX, 30) < lit);
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

        // As a Pre drew it (and Mojo's 48 px icon on a 52 px row): the icon
        // 48/52 of the height, centred on the icon pill whether the entry is
        // split or not, the text 1.34 heights in either way.
        function test_phoneIconAndTextSitWhereAPresDid() {
            var single = item;
            var group = createTemporaryObject(groupComponent, null);
            group.parent = item.parent;
            [single, group].forEach(function(e) {
                var icon = findChild(e, "notificationIcon");
                fuzzyCompare(icon.height, e.height * 48 / 52, 0.01, "icon size");
                fuzzyCompare(icon.x + icon.width / 2, e.iconPillWidth / 2, 0.01, "centred on the icon pill");
                // anchored, so on a whole pixel
                fuzzyCompare(icon.y + icon.height / 2, e.height / 2, 0.5, "centred top to bottom");
            });
            var singleTitle = find(single, single.title);
            var groupTitle = find(group, "top title");
            fuzzyCompare(singleTitle.mapToItem(single, 0, 0).x, single.height * 1.34, 0.01);
            fuzzyCompare(groupTitle.mapToItem(group, 0, 0).x, group.height * 1.34, 0.01);
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
