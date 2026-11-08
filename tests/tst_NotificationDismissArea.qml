import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * The expanded notification area collapses on a press anywhere outside it, and
 * when the launcher or Just Type opens; the press is taken, so nothing
 * underneath reacts to it. Wired as CardsArea wires it, around the real
 * NotificationArea (phone: above the gesture area, the dismiss area above it)
 * and the real NotificationAreaTablet (in the status bar, its list hanging
 * from the bar over the dismiss area). Every case runs on both.
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

    // CardsArea on a phone: the area over the gesture area, the dismiss area
    // from the top down to it.
    Component {
        id: phoneShell
        Item {
            property alias area: area
            property alias dismiss: dismiss
            // a point outside the area
            property point outside: Qt.point(100, 50)
            function openArea() {
                mouseClickOn(area, area.width - 20, area.height / 2);
            }
            anchors.fill: parent

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
        }
    }

    // CardsArea on a tablet: the area in the status bar, its list hanging
    // below the bar; the dismiss area covers the screen under the bar.
    Component {
        id: tabletShell
        Item {
            property alias area: area
            property alias dismiss: dismiss
            property point outside: Qt.point(20, 400)
            function openArea() {
                area.clicked();   // as the bar does for a tap on its icons
            }
            anchors.fill: parent

            NotificationDismissArea {
                id: dismiss
                anchors.fill: parent
                z: 2
                notificationArea: area
                launcher: fakeLauncher
            }

            Item {
                id: bar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 30
                z: 2   // declared after the dismiss area, as in CardsArea

                NotificationAreaTablet {
                    id: area
                    anchors.top: parent.top
                    anchors.right: parent.right
                    height: parent.height
                    width: 100
                    compositorInstance: QtObject {
                        property ListModel surfaceModel: ListModel {}
                    }
                    windowManagerInstance: windowManager
                    maxDashboardWindowHeight: 240
                }
            }
        }
    }

    Component {
        id: noAreaDismiss
        NotificationDismissArea { anchors.fill: parent; z: 3 }
    }

    function mouseClickOn(item, x, y) {
        testCase.mouseClick(item, x, y);
    }

    TestCase {
        id: testCase
        name: "NotificationDismissArea"
        when: windowShown

        property int stamp: 0
        property Item shell: null
        property Item area: shell ? shell.area : null
        property Item dismiss: shell ? shell.dismiss : null

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

        function build(form) {
            shell = createTemporaryObject(form === "tablet" ? tabletShell : phoneShell, root);
            verify(shell);
            tryCompare(area, "state", "hidden");
        }

        // two notifications, banners gone, then open it as a tap on the icons does
        function openArea() {
            addToast();
            addToast();
            bannerModel().clear();
            tryCompare(area, "state", "minimized");
            tryVerify(function() { return area.height > 0; });
            shell.openArea();
            tryCompare(area, "state", "open");
            compare(windowManager.countOf("minimizeNotificationArea"), 1);
            tryVerify(function() { return dismiss.enabled && dismiss.height > 0; });
        }

        function pressOutside() {
            mousePress(root, shell.outside.x, shell.outside.y);
        }
        function releaseOutside() {
            mouseRelease(root, shell.outside.x, shell.outside.y);
        }

        function init() {
            clearToasts();
            fakeLauncher.fullLauncherVisible = false;
            fakeLauncher.justTypeLauncherActive = false;
            windowManager.tapActions = [];
            underneath.presses = 0;
        }

        function cleanup() {
            clearToasts();
            shell = null;
        }

        function forms() {
            return [ { tag: "phone", form: "phone" }, { tag: "tablet", form: "tablet" } ];
        }

        function test_offUnlessOpen_data() { return forms(); }
        function test_offUnlessOpen(data) {
            build(data.form);
            verify(!dismiss.enabled);
            pressOutside();
            releaseOutside();
            compare(underneath.presses, 1);

            addToast();
            bannerModel().clear();
            tryCompare(area, "state", "minimized");
            verify(!dismiss.enabled);
        }

        function test_pressOutsideCollapsesAndIsTaken_data() { return forms(); }
        function test_pressOutsideCollapsesAndIsTaken(data) {
            build(data.form);
            openArea();
            pressOutside();
            compare(area.state, "minimized");
            compare(underneath.presses, 0);
            releaseOutside();
            compare(underneath.presses, 0);
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
            verify(!dismiss.enabled);

            // and the next press is an ordinary one again
            pressOutside();
            releaseOutside();
            compare(underneath.presses, 1);
        }

        // a press on the open area itself is the area's, and leaves it open
        function test_pressOnAreaKeepsItOpen_data() { return forms(); }
        function test_pressOnAreaKeepsItOpen(data) {
            build(data.form);
            openArea();
            // the open list, once its height has animated in
            var list = null;
            for (var i = 0; i < area.children.length; i++)
                if (area.children[i].orientation !== undefined && area.children[i].visible)
                    list = area.children[i];
            verify(list);
            tryVerify(function() { return list.height > 20; });
            var p = list.mapToItem(root, list.width / 2, list.height / 2);
            mousePress(root, p.x, p.y);
            mouseRelease(root, p.x, p.y);
            compare(underneath.presses, 0);
            compare(area.state, "open");
        }

        function test_gestureAreaTapStillCollapses_data() { return forms(); }
        function test_gestureAreaTapStillCollapses(data) {
            build(data.form);
            openArea();
            windowManager.tap();
            compare(area.state, "minimized");
            compare(windowManager.tapActions.length, 0);
        }

        function test_launcherCollapses_data() { return forms(); }
        function test_launcherCollapses(data) {
            build(data.form);
            openArea();
            fakeLauncher.fullLauncherVisible = true;
            compare(area.state, "minimized");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
        }

        function test_justTypeCollapses_data() { return forms(); }
        function test_justTypeCollapses(data) {
            build(data.form);
            openArea();
            fakeLauncher.justTypeLauncherActive = true;
            compare(area.state, "minimized");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
        }

        // The lock screen hides the area's Loader. That already collapsed it
        // (the "minimized" state's when reads the list's effective
        // visibility), but left the tap action behind.
        function test_lockScreenCollapsesAndDropsTapAction_data() { return forms(); }
        function test_lockScreenCollapsesAndDropsTapAction(data) {
            build(data.form);
            openArea();
            area.visible = false;
            verify(!dismiss.enabled);
            compare(area.state, "minimized");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
            pressOutside();
            releaseOutside();
            compare(underneath.presses, 1);
        }

        // the last notification going while open: no tap action left behind
        function test_lastNotificationGoneDropsTapAction_data() { return forms(); }
        function test_lastNotificationGoneDropsTapAction(data) {
            build(data.form);
            openArea();
            clearToasts();
            tryCompare(area, "state", "hidden");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
        }

        // a new notification while open shows its banner instead: same
        function test_newNotificationDropsTapAction_data() { return forms(); }
        function test_newNotificationDropsTapAction(data) {
            build(data.form);
            openArea();
            addToast();
            tryCompare(area, "state", "banner");
            compare(windowManager.countOf("minimizeNotificationArea"), 0);
            verify(!dismiss.enabled);
        }

        // opening again after any of those registers exactly one action
        function test_reopenRegistersOne_data() { return forms(); }
        function test_reopenRegistersOne(data) {
            build(data.form);
            openArea();
            clearToasts();
            tryCompare(area, "state", "hidden");
            openArea();
            compare(windowManager.countOf("minimizeNotificationArea"), 1);
        }

        // no notification area at all (CardsArea's phone Loader on a tablet
        // before this, or a shell without one): off, and nothing breaks
        function test_noAreaStaysOff() {
            var none = createTemporaryObject(noAreaDismiss, root);
            verify(none);
            verify(!none.enabled);
            pressOutside_at(100, 50);
            compare(underneath.presses, 1);
            none.collapse();
        }
        function pressOutside_at(x, y) {
            mousePress(root, x, y);
            mouseRelease(root, x, y);
        }
    }
}
