import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * The phone's expanded notification area collapses on a press anywhere above
 * it, and when the launcher or Just Type opens; the press is taken, so nothing
 * underneath reacts to it. Wired as CardsArea wires it, around the real
 * NotificationArea.
 *
 * Its tap action ("minimizeNotificationArea", for a tap on the gesture area)
 * goes whenever the area leaves "open" - also when the last notification goes
 * or a new one arrives. A stale one ate the next gesture-area tap.
 *
 * An Item is the root, not the TestCase: with the TestCase as the root, no
 * mouse event reaches the areas.
 */
Item {
    id: root
    width: 320
    height: 480

    // WindowManager's tap-action stack, as WindowManagerServices.js keeps it
    Item {
        id: windowManager
        property var tapActions: []
        function addTapAction(id, fct, data) {
            tapActions.push({ "id": id, "fct": fct, "data": data });
        }
        function removeTapAction(id) {
            tapActions = tapActions.filter(function(a) { return a.id !== id; });
        }
        function countOf(id) {
            return tapActions.filter(function(a) { return a.id === id; }).length;
        }
        function tap() {
            var a = tapActions.pop();
            if (a && a.fct)
                a.fct(a.data);
        }
    }

    Item {
        id: fakeLauncher
        property bool fullLauncherVisible: false
        property bool justTypeLauncherActive: false
    }

    // what a card or the launcher would be: anything under the dismiss area
    MouseArea {
        id: underneath
        anchors.fill: parent
        property int presses: 0
        onPressed: presses++
    }

    // CardsArea's Loader hides it under the lock screen; visible here
    NotificationArea {
        id: area
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        compositorInstance: QtObject {
            property ListModel surfaceModel: ListModel {}
        }
        windowManagerInstance: windowManager
        maxDashboardWindowHeight: 240
    }

    NotificationDismissArea {
        id: dismiss
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: area.top
        z: 2
        notificationArea: area
        launcher: fakeLauncher
    }

    // the tablet: CardsArea's Loader stays empty, its item is null
    Component {
        id: tabletDismiss
        NotificationDismissArea {
            anchors.fill: parent
            z: 3
            notificationArea: null
            launcher: fakeLauncher
        }
    }

    TestCase {
        name: "NotificationDismissArea"
        when: windowShown

        property int stamp: 0

        function addToast() {
            stamp++;
            ModelSingletons.toastModel.append({
                "message": "message " + stamp,
                "title": "title " + stamp,
                "type": "standard",
                "sourceId": "com.example.app" + stamp,
                "timestamp": String(1000 + stamp),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "com.example.app" + stamp } }
            });
        }

        // one row at a time: the merged model follows rowsAboutToBeRemoved,
        // which ListModel.clear() does not send
        function clearToasts() {
            var m = ModelSingletons.toastModel;
            while (m.count > 0)
                m.remove(m.count - 1);
        }

        function bannerModel() {
            for (var i = 0; i < area.children.length; i++)
                if (area.children[i].popupModel !== undefined)
                    return area.children[i].popupModel;
            return null;
        }

        // two notifications, banners gone, then a tap on the icons opens it
        function openArea() {
            addToast();
            addToast();
            bannerModel().clear();
            tryCompare(area, "state", "minimized");
            tryVerify(function() { return area.height > 0; });
            mouseClick(area, area.width - 20, area.height / 2);
            tryCompare(area, "state", "open");
            compare(windowManager.countOf("minimizeNotificationArea"), 1);
            tryVerify(function() { return dismiss.enabled && dismiss.height > 0; });
        }

        function init() {
            area.visible = true;
            fakeLauncher.fullLauncherVisible = false;
            fakeLauncher.justTypeLauncherActive = false;
            clearToasts();
            windowManager.tapActions = [];
            underneath.presses = 0;
            tryCompare(area, "state", "hidden");
        }

        function test_offUnlessOpen() {
            verify(!dismiss.enabled);
            mousePress(root, 100, 100);
            mouseRelease(root, 100, 100);
            compare(underneath.presses, 1);

            addToast();
            bannerModel().clear();
            tryCompare(area, "state", "minimized");
            verify(!dismiss.enabled);
        }

        function test_pressAboveCollapsesAndIsTaken() {
            openArea();
            mousePress(root, 100, 50);
            compare(area.state, "minimized");
            compare(underneath.presses, 0);
            mouseRelease(root, 100, 50);
            compare(underneath.presses, 0);
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
            verify(!dismiss.enabled);

            // and the next press is an ordinary one again
            mouseClick(root, 100, 50);
            compare(underneath.presses, 1);
        }

        function test_gestureAreaTapStillCollapses() {
            openArea();
            windowManager.tap();
            compare(area.state, "minimized");
            compare(windowManager.tapActions.length, 0);
        }

        function test_launcherCollapses() {
            openArea();
            fakeLauncher.fullLauncherVisible = true;
            compare(area.state, "minimized");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
        }

        function test_justTypeCollapses() {
            openArea();
            fakeLauncher.justTypeLauncherActive = true;
            compare(area.state, "minimized");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
        }

        function test_tabletStaysOff() {
            var tablet = createTemporaryObject(tabletDismiss, root);
            verify(tablet);
            verify(!tablet.enabled);
            mouseClick(root, 100, 50);
            compare(underneath.presses, 1);
            fakeLauncher.fullLauncherVisible = true;   // no area to collapse, no error
            tablet.collapse();
        }

        // The lock screen hides the area's Loader. That already collapsed it
        // (the "minimized" state's when reads the list's effective
        // visibility), but left the tap action behind.
        function test_lockScreenCollapsesAndDropsTapAction() {
            openArea();
            area.visible = false;
            verify(!dismiss.enabled);
            compare(area.state, "minimized");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
            mouseClick(root, 100, 50);
            compare(underneath.presses, 1);
        }

        // the last notification going while open: no tap action left behind
        function test_lastNotificationGoneDropsTapAction() {
            openArea();
            clearToasts();
            tryCompare(area, "state", "hidden");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
        }

        // a new notification while open shows its banner instead: same
        function test_newNotificationDropsTapAction() {
            openArea();
            addToast();
            tryCompare(area, "state", "banner");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
            verify(!dismiss.enabled);
        }

        // opening again after any of those registers exactly one action
        function test_reopenRegistersOne() {
            openArea();
            clearToasts();
            tryCompare(area, "state", "hidden");
            openArea();
            compare(windowManager.countOf("minimizeNotificationArea"), 1);
        }
    }
}
