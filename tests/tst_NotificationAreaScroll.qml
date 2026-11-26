import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0
import LuneOS.System 1.0

import "../qml/Notifications"
import "../qml/Utils"

/*
 * The phone's open list lays its rows out as webOS 2.x's LunaSysMgr did: as
 * tall as maxDashboardWindowHeight allows, the newest row at the bottom, and
 * it comes to rest with a row's bottom edge on the list's bottom edge. What
 * does not fit is cut at the top, under a shadow, never at the bottom.
 */
Item {
    id: root
    width: 480
    height: 800

    Item {
        id: windowManager
        state: "normal"
        states: [ State { name: "firstuse" }, State { name: "normal" } ]
        function addTapAction(id, fct, data) {}
        function removeTapAction(id) {}
    }

    Item {
        id: launcherInstance
        function launchApplication(id, params, successCB) {}
    }

    Compositor { id: compositor }

    NotificationsMergedModel {
        id: sharedModel
        compositorInstance: compositor
        held: windowManager.state === "firstuse"
    }

    Component {
        id: phoneArea
        NotificationArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            compositorInstance: compositor
            windowManagerInstance: windowManager
            mergedModel: sharedModel
        }
    }

    TestCase {
        name: "NotificationAreaScroll"
        when: windowShown

        property int serial: 0
        property real row: 0
        property real gap: 0

        function addToast(title) {
            serial++;
            ModelSingletons.toastModel.append({
                "message": "message " + serial,
                "title": title,
                "type": "standard",
                "sourceId": "com.example.app" + serial,
                "ownerId": "com.example.app" + serial,
                "iconPath": "",
                "timestamp": String(1000 + serial),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "org.webosports.app.settings" } }
            });
        }

        function cleanup() {
            ModelSingletons.toastModel.clear();
            tryCompare(sharedModel, "count", 0);
        }

        function openWith(rows, maxHeight) {
            var area = createTemporaryObject(phoneArea, root, { "maxDashboardWindowHeight": maxHeight });
            for (var i = 0; i < rows; i++)
                addToast("toast " + i);
            findChild(area, "bannerPopupArea").popupModel.clear();
            area.state = "open";
            var list = findChild(area, "openListView");
            tryCompare(list, "count", rows);
            // the list grows to its height with an animation
            tryVerify(() => list.height > 0 && list.height === Math.min(Math.round(maxHeight), list.contentHeight),
                      2000, "open at its full height");
            wait(50);
            return area;
        }

        function initTestCase() {
            var area = openWith(2, 1000);
            row = sharedModel.get(0).notifHeight;
            gap = findChild(area, "openListView").spacing;
            verify(row > 0 && gap > 0);
            cleanup();
        }

        function offset(list) {
            return list.contentY - list.originY;
        }

        // How far the list is from resting with row i's bottom on its bottom.
        function offRowBottom(list, i) {
            return offset(list) + list.height - ((i + 1) * row + i * gap);
        }

        // A slow drag (no flick) of dy, down towards the older rows.
        function drag(list, dy) {
            var x = list.width / 2, y = 10, steps = 20;
            mousePress(list, x, y);
            for (var i = 1; i <= steps; i++)
                mouseMove(list, x, y + dy * i / steps, 30, Qt.LeftButton);
            wait(200);
            mouseRelease(list, x, y + dy, Qt.LeftButton, Qt.NoModifier, 30);
        }

        function restsOnARowBottom(list) {
            for (var i = 0; i < list.count; i++) {
                if (Math.abs(offRowBottom(list, i)) < 1)
                    return true;
            }
            return false;
        }

        // The Q25 case: room for three rows and most of a fourth.
        function test_whatDoesNotFitIsCutAtTheTop() {
            var area = openWith(5, 3 * row + 2 * gap + 0.8 * row);
            var list = findChild(area, "openListView");
            tryCompare(list, "height", Math.round(3 * row + 2 * gap + 0.8 * row));
            tryVerify(() => Math.abs(offRowBottom(list, 4)) < 1, 2000,
                      "opened on the newest, its bottom on the list's");
            verify(list.interactive);
            tryCompare(findChild(area, "dashboardTopMask"), "visible", true);
            compare(findChild(area, "dashboardBottomMask").visible, false);
        }

        function test_aDragComesToRestOnARowBottom() {
            var area = openWith(6, 3 * row + 2 * gap + 0.5 * row);
            var list = findChild(area, "openListView");
            tryVerify(() => Math.abs(offRowBottom(list, 5)) < 1, 2000);

            // down by a row and a half, towards the older rows
            drag(list, 1.5 * (row + gap));
            tryVerify(() => !list.moving && restsOnARowBottom(list), 3000,
                      "rests on a row's bottom, at " + offset(list));
            verify(offRowBottom(list, 5) < -1, "it moved off the newest");
            tryCompare(findChild(area, "dashboardBottomMask"), "visible", true);
            compare(findChild(area, "dashboardTopMask").visible, true);
        }

        // As in 2.x: the stops are only the bottom-aligned ones, so going
        // all the way up still leaves the oldest cut when the rows overflow
        // by less than a row.
        function test_theTopmostStopIsTheFirstRowThatFillsTheList() {
            var area = openWith(4, 3 * row + 2 * gap + 0.5 * row);
            var list = findChild(area, "openListView");
            tryVerify(() => Math.abs(offRowBottom(list, 3)) < 1, 2000);
            drag(list, 3 * (row + gap));
            tryVerify(() => !list.moving && restsOnARowBottom(list), 3000);
            compare(list.atYBeginning, false, "the oldest stays cut");
            compare(Math.round(offRowBottom(list, 3)), 0,
                    "the fourth row's bottom is the only stop");
        }

        function test_aShortListShowsEverythingWithoutShadows() {
            var area = openWith(2, 1000);
            var list = findChild(area, "openListView");
            tryCompare(list, "height", list.contentHeight);
            verify(!list.interactive);
            compare(offset(list), 0);
            compare(findChild(area, "dashboardTopMask").visible, false);
            compare(findChild(area, "dashboardBottomMask").visible, false);
        }

        // An entry going away keeps the list resting on a row's bottom.
        function test_removingARowKeepsTheBottomAligned() {
            var area = openWith(5, 3 * row + 2 * gap + 0.8 * row);
            var list = findChild(area, "openListView");
            tryVerify(() => Math.abs(offRowBottom(list, 4)) < 1, 2000);
            ModelSingletons.toastModel.remove(4);
            tryCompare(list, "count", 4);
            tryVerify(() => restsOnARowBottom(list), 2000, "at " + offset(list));
        }
    }
}
