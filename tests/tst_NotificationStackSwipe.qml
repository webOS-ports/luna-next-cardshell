import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * A stack of notifications swiped in the real areas, the phone's
 * NotificationArea and the tablet's NotificationAreaTablet: a drag from the
 * icon of a group closes every toast of the group with notificationmgr, a
 * drag on its text the newest only; another app's toast stays either way.
 *
 * SwipeableNotification and the merged model's delegate are tested on their
 * own (tst_SwipeableNotification, tst_NotificationGroups); this is the path
 * between them, through the area's loader, which once dropped the whole-group
 * close and left the entry slid out with all its toasts still there.
 *
 * An Item is the root, not the TestCase: with the TestCase as the root, no
 * mouse event reaches the areas.
 */
Item {
    id: root
    width: 320
    height: 480

    Item {
        id: windowManager
        function addTapAction(id, fct, data) {}
        function removeTapAction(id) {}
    }

    Component {
        id: phoneArea
        NotificationArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            compositorInstance: QtObject {
                property ListModel surfaceModel: ListModel {}
            }
            windowManagerInstance: windowManager
            mergedModel: NotificationsMergedModel {}
            maxDashboardWindowHeight: 240
            function openIt() { testCase.mouseClick(this, width - 20, height / 2); }
        }
    }

    Component {
        id: tabletArea
        NotificationAreaTablet {
            anchors.top: parent.top
            anchors.right: parent.right
            height: 30
            width: 300
            compositorInstance: QtObject {
                property ListModel surfaceModel: ListModel {}
            }
            windowManagerInstance: windowManager
            mergedModel: NotificationsMergedModel {}
            maxDashboardWindowHeight: 240
            function openIt() { clicked(); }
        }
    }

    TestCase {
        id: testCase
        name: "NotificationStackSwipe"
        when: windowShown

        property int stamp: 0
        property Item area: null

        function addToast(sourceId, groupId) {
            stamp++;
            ModelSingletons.toastModel.append({
                "message": "message " + stamp,
                "title": "title " + stamp,
                "type": "standard",
                "sourceId": sourceId,
                "groupId": groupId,
                "timestamp": String(1000 + stamp),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": sourceId } }
            });
        }

        function clearToasts() {
            var m = ModelSingletons.toastModel;
            while (m.count > 0)
                m.remove(m.count - 1);
        }

        function sources() {
            var found = [];
            for (var i = 0; i < ModelSingletons.toastModel.count; i++)
                found.push(ModelSingletons.toastModel.get(i).sourceId);
            return found.sort();
        }

        function find(node, test) {
            if (test(node))
                return node;
            for (var i = 0; i < node.children.length; i++) {
                var hit = find(node.children[i], test);
                if (hit)
                    return hit;
            }
            if (node.contentItem && node.contentItem !== node) {
                var inner = find(node.contentItem, test);
                if (inner)
                    return inner;
            }
            return null;
        }

        function bannerModel() {
            for (var i = 0; i < area.children.length; i++)
                if (area.children[i].popupModel !== undefined)
                    return area.children[i].popupModel;
            return null;
        }

        // Three toasts of one group and one of another app, the area open,
        // and the group's entry (SwipeableNotification) once it is laid out.
        function openWithStack(form) {
            area = createTemporaryObject(form === "tablet" ? tabletArea : phoneArea, root);
            verify(area);
            addToast("com.example.chat", "thread");
            addToast("com.example.chat", "thread");
            addToast("com.example.chat", "thread");
            addToast("com.example.other");
            bannerModel().clear();
            tryVerify(function() { return area.state === "minimized"; });
            tryVerify(function() { return area.height > 0; });
            area.openIt();
            tryCompare(area, "state", "open");
            var entry = null;
            tryVerify(function() {
                entry = find(area, function(n) {
                    return n.requestGroupDestruction !== undefined && n.layered && n.visible &&
                            n.width > 100 && n.height > 10;
                });
                return entry !== null;
            }, 3000, "the group's entry is shown, stacked");
            wait(500);   // the list's height animation
            return entry;
        }

        function dragOn(entry, fromX) {
            var y = entry.height / 2, steps = 20, dx = entry.width * 0.7;
            mousePress(entry, fromX, y);
            for (var i = 1; i <= steps; ++i)
                mouseMove(entry, fromX + dx * i / steps, y, 30, Qt.LeftButton);
            wait(300);
            mouseRelease(entry, fromX + dx, y);
        }

        function init() {
            clearToasts();
        }

        function cleanup() {
            clearToasts();
            area = null;
        }

        function forms() {
            return [ { tag: "phone", form: "phone" }, { tag: "tablet", form: "tablet" } ];
        }

        function test_iconSwipeClosesTheWholeGroup_data() { return forms(); }
        function test_iconSwipeClosesTheWholeGroup(data) {
            var entry = openWithStack(data.form);
            verify(entry.iconZoneWidth > 0);
            dragOn(entry, entry.iconZoneWidth / 3);
            tryCompare(ModelSingletons.toastModel, "count", 1, 3000);
            compare(sources(), ["com.example.other"]);
        }

        function test_textSwipeClosesTheNewestOnly_data() { return forms(); }
        function test_textSwipeClosesTheNewestOnly(data) {
            var entry = openWithStack(data.form);
            dragOn(entry, entry.width / 2);
            tryCompare(ModelSingletons.toastModel, "count", 3, 3000);
            compare(sources(), ["com.example.chat", "com.example.chat", "com.example.other"]);
        }
    }
}
