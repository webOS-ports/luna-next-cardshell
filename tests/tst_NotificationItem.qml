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

    TestCase {
        name: "NotificationItem"
        when: windowShown

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
