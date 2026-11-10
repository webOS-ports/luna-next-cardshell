import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0
import LuneOS.System 1.0

import "../qml/Notifications"
import "../qml/Utils"

/*
 * Settings' Notifications page moves the list between the bottom (the phone's
 * NotificationArea) and the status bar (the tablet's NotificationAreaTablet)
 * while the shell runs, and the area that is up is made afresh. Both show
 * CardsArea's one model: what was listed stays listed, a dashboard window
 * that was up is up in the new area, and nothing that had its banner gets a
 * second one. A toast that comes in afterwards has its banner in the new area.
 */
Item {
    id: root
    width: 480
    height: 640

    Item {
        id: windowManager
        state: "normal"
        states: [ State { name: "firstuse" }, State { name: "normal" } ]
        property var tapActions: []
        function addTapAction(id, fct, data) {
            tapActions.push({ "id": id, "fct": fct, "data": data });
        }
        function removeTapAction(id) {
            tapActions = tapActions.filter(function(a) { return a.id !== id; });
        }
    }

    Item {
        id: launcherInstance
        function launchApplication(id, params, successCB) {}
    }

    Compositor { id: compositor }

    // Settings' side of the preference store, for the style
    SystemPreferences {
        id: prefs
        keys: ["notificationStyle"]
    }

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
            maxDashboardWindowHeight: 240
        }
    }

    Component {
        id: tabletArea
        NotificationAreaTablet {
            anchors.top: parent.top
            anchors.right: parent.right
            height: 30
            width: 100
            compositorInstance: compositor
            windowManagerInstance: windowManager
            mergedModel: sharedModel
            maxDashboardWindowHeight: 240
        }
    }

    Component {
        id: dashboardWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_FLOATING"
            property string appId: "com.example.dash"
            property var windowProperties: ({})
            function changeSize(size) {}
        }
    }

    TestCase {
        name: "NotificationAreaSwap"
        when: windowShown

        property int serial: 0

        function addToast(type, title) {
            serial++;
            ModelSingletons.toastModel.append({
                "message": "message " + serial,
                "title": title,
                "type": type,
                "sourceId": "com.example.app" + serial,
                "ownerId": "com.example.app" + serial,
                "iconPath": "",
                "timestamp": String(1000 + serial),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "org.webosports.app.settings" } }
            });
        }

        function banners(area) {
            return findChild(area, "bannerPopupArea").popupModel;
        }

        function cleanup() {
            prefs.set("notificationStyle", "auto");
            tryCompare(NotificationLayout, "tabletStyle", false);
            while (compositor.surfaceModel.count > 0)
                compositor.closeWindow(compositor.surfaceModel.get(0).obj);
            ModelSingletons.toastModel.clear();
            tryCompare(sharedModel, "count", 0);
        }

        function shownDividers(area) {
            var list = findChild(area, "openListView");
            var n = 0;
            for (var i = 0; i < list.contentItem.children.length; i++) {
                var row = list.contentItem.children[i];
                for (var j = 0; j < row.children.length; j++) {
                    if (row.children[j].objectName === "rowDivider" && row.children[j].visible)
                        n++;
                }
            }
            return n;
        }

        // Tablet rows have no bar of their own: at the bottom they sit on the
        // drop-down's panel, parted by its dividers; phone rows on their bars.
        function test_tabletRowsAtTheBottomHaveTheDropDownsBackdrop() {
            tryVerify(() => prefs.loaded);
            var area = createTemporaryObject(phoneArea, root);
            addToast("standard", "one");
            addToast("standard", "two");
            addToast("standard", "three");
            banners(area).clear();
            area.state = "open";
            var bg = findChild(area, "openListViewBg");
            var list = findChild(area, "openListView");
            tryCompare(list, "count", 3);
            verify(!bg.visible, "a phone's rows have their own bars");
            compare(shownDividers(area), 0);

            prefs.set("notificationStyle", "tablet");
            tryCompare(bg, "visible", true);
            compare(bg.y, list.y);
            verify(bg.width > list.width && bg.height > list.height, "the panel goes round the rows");
            tryCompare(list, "spacing", 2);
            // and it shows: between the rows it is the panel's grey, not the
            // area's black
            wait(50);
            var shot = grabImage(area);
            var c = shot.pixel(Math.round(list.x + list.width / 2), Math.round(list.y + 1));
            verify(c.r > 0.1 && c.g > 0.1 && c.b > 0.1, "the panel is drawn: " + c);
            tryVerify(() => shownDividers(area) === 2, 1000, "one between each two rows, none under the last");

            prefs.set("notificationStyle", "phone");
            tryCompare(bg, "visible", false);
            tryVerify(() => shownDividers(area) === 0);
        }

        function swaps_data() {
            return [ { tag: "bottom to top", from: phoneArea, to: tabletArea },
                     { tag: "top to bottom", from: tabletArea, to: phoneArea } ];
        }

        function test_theListComesOver_data() { return swaps_data(); }
        function test_theListComesOver(data) {
            var old = createTemporaryObject(data.from, root);
            addToast("standard", "a sticky one");
            compare(sharedModel.count, 1);
            compare(banners(old).count, 1);

            var window = dashboardWindow.createObject(compositor);
            compositor.surfaceModel.append({ obj: window });
            compare(sharedModel.count, 2);

            old.destroy();
            wait(0);
            var area = createTemporaryObject(data.to, root);
            compare(area.mergedModel.count, 2, "the toast and the dashboard are still listed");
            compare(banners(area).count, 0, "no second banner for what had one");

            addToast("standard", "a new one");
            compare(sharedModel.count, 3);
            compare(banners(area).count, 1, "a new toast has its banner here");
        }

        // As before the model was shared: a dashboard coming in closes the
        // open list down to its icons, in whichever area is up.
        function test_aNewDashboardClosesTheOpenList_data() { return swaps_data(); }
        function test_aNewDashboardClosesTheOpenList(data) {
            var area = createTemporaryObject(data.to, root);
            addToast("standard", "a sticky one");
            banners(area).clear();
            area.state = "open";
            compare(area.state, "open");
            var window = dashboardWindow.createObject(compositor);
            compositor.surfaceModel.append({ obj: window });
            compare(area.state, "minimized");
        }

        // The two Loaders change on the one binding, in no set order: the new
        // area may take the dashboard's window before the old one goes, and
        // the old one going must not hide it then.
        function test_aWindowTakenBeforeTheOldAreaGoesStaysUp_data() { return swaps_data(); }
        function test_aWindowTakenBeforeTheOldAreaGoesStaysUp(data) {
            var old = createTemporaryObject(data.from, root);
            var window = dashboardWindow.createObject(compositor);
            compositor.surfaceModel.append({ obj: window });
            old.state = "open";
            tryVerify(() => window.visible && window.parent !== null && window.parent !== compositor,
                      2000, "the old area shows the window");
            var oldParent = window.parent;

            var area = createTemporaryObject(data.to, root);
            area.state = "open";
            tryVerify(() => window.parent !== oldParent, 2000, "the new area takes the window");
            old.destroy();
            wait(0);
            verify(window.visible, "still shown once the old area has gone");
            verify(window.parent !== null);
        }
    }
}
