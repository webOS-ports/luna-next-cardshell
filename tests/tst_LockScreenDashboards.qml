import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0
import LuneOS.System 1.0

import "../qml/Notifications"
import "../qml/LockScreen"
import "../qml/Utils"

/*
 * The notifications on the lock screen, as LunaSysMgr's LockWindow showed
 * its dashboards there (DashboardAlerts): the merged model's entries, the
 * dashboard windows taken from the notification area while the lock screen
 * shows them and given back after; the newest at the bottom of a phone's
 * stack of four, fading out upwards (2.2.4), at the top of the tablet's
 * panel of six (3.0.5); taps only for a dashboard that is clickable while
 * locked. Run against luneos-components' compositor mock.
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
        property int launches: 0
        function launchApplication(id, params, successCB) { launches++; }
    }

    Compositor { id: compositor }

    SystemPreferences {
        id: prefs
        keys: ["notificationStyle"]
    }

    NotificationsMergedModel {
        id: sharedModel
        compositorInstance: compositor
        onLockScreen: lockList.active
    }

    NotificationArea {
        id: area
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        compositorInstance: compositor
        windowManagerInstance: windowManager
        mergedModel: sharedModel
        maxDashboardWindowHeight: 240
    }

    LockScreenDashboards {
        id: lockList
        width: root.width
        height: 600
        availableHeight: 600
        mergedModel: sharedModel
        compositorInstance: compositor
        active: false
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
            property size askedFor: Qt.size(0, 0)
            property int presses: 0
            function changeSize(size) { askedFor = size; }
            MouseArea {
                anchors.fill: parent
                onPressed: parent.presses++
            }
        }
    }

    TestCase {
        name: "LockScreenDashboards"
        when: windowShown

        property int serial: 0

        function addDashboard(props) {
            var window = dashboardWindow.createObject(compositor, { windowProperties: props || {} });
            compositor.surfaceModel.append({ obj: window });
            return window;
        }

        function addToast(title, type) {
            serial++;
            ModelSingletons.toastModel.append({
                "message": "message " + serial,
                "title": title,
                "type": type || "standard",
                "sourceId": "com.example.app" + serial,
                "ownerId": "com.example.app" + serial,
                "iconPath": "",
                "timestamp": String(1000 + serial),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "org.webosports.app.settings" } }
            });
        }

        function rows() {
            var list = [];
            var rowsArea = findChild(lockList, "lockScreenDashboardsRows");
            for (var i = 0; i < rowsArea.children.length; i++) {
                if (rowsArea.children[i].objectName === "lockScreenRow")
                    list.push(rowsArea.children[i]);
            }
            return list;
        }

        // The lock screen's row for an entry, counted from the newest.
        function rowFromNewest(k) {
            var all = rows();
            for (var i = 0; i < all.length; i++) {
                if (all[i].fromNewest === k)
                    return all[i];
            }
            return null;
        }

        function isOnLockScreen(window) {
            for (var p = window.parent; p; p = p.parent) {
                if (p === lockList)
                    return true;
            }
            return false;
        }

        function cleanup() {
            lockList.active = false;
            area.state = "minimized";
            prefs.set("notificationStyle", "auto");
            tryCompare(NotificationLayout, "tabletStyle", false);
            while (compositor.surfaceModel.count > 0)
                compositor.closeWindow(compositor.surfaceModel.get(0).obj);
            ModelSingletons.toastModel.clear();
            tryCompare(sharedModel, "count", 0);
            launcherInstance.launches = 0;
            areaBanners(area).clear();
        }

        function test_nothing_while_not_shown() {
            addDashboard();
            addToast("a");
            tryCompare(sharedModel, "count", 2);
            verify(!lockList.visible);
            compare(rows().length, 0, "no second view of the entries until the lock screen shows them");
        }

        // The phone's area makes its rows only while it is open.
        function test_the_lock_screen_takes_the_dashboards_and_gives_them_back() {
            var window = addDashboard();
            area.state = "open";
            tryVerify(() => window.visible && window.parent !== null && window.parent !== compositor,
                      2000, "the notification area shows the window");
            var areaParent = window.parent;
            verify(!isOnLockScreen(window));

            lockList.active = true;
            tryVerify(() => isOnLockScreen(window), 2000, "the lock screen takes the window");
            verify(window.visible);
            verify(lockList.visible);
            compare(window.askedFor.width, lockList.rowWidth, "the client is sized for the lock screen's row");

            lockList.active = false;
            tryVerify(() => window.parent === areaParent, 2000, "the notification area takes it back");
            verify(window.visible, "and shows it again");
            compare(rows().length, 0);
        }

        function test_a_dashboard_coming_in_while_locked_shows_on_the_lock_screen() {
            lockList.active = true;
            var window = addDashboard();
            tryVerify(() => isOnLockScreen(window) && window.visible, 2000);
            area.state = "open";
            lockList.active = false;
            tryVerify(() => window.parent !== null && !isOnLockScreen(window) && window.visible, 2000);
        }

        // 2.2.4: four at most, the newest at the bottom, the third and the
        // fourth from it at 0.5 and 0.15.
        function test_phone_stack() {
            for (var i = 0; i < 5; i++)
                addToast("t" + i);
            tryCompare(sharedModel, "count", 5);
            lockList.active = true;
            tryCompare(lockList, "shownRows", 4);

            var shown = rows().filter(r => r.visible);
            compare(shown.length, 4);
            var newest = rowFromNewest(0);
            var rowsArea = findChild(lockList, "lockScreenDashboardsRows");
            compare(newest.y + newest.height, rowsArea.height, "the newest rests on the bottom");
            compare(rowsArea.y + rowsArea.height, lockList.height, "and the stack on the bottom of the area");
            verify(rowFromNewest(1).y < newest.y, "the older above it");
            compare(rowFromNewest(0).opacity, 1);
            compare(rowFromNewest(1).opacity, 1);
            compare(rowFromNewest(2).opacity, 0.5);
            compare(rowFromNewest(3).opacity, 0.15);
            verify(!rowFromNewest(4).visible, "a fifth is not shown");
            verify(!findChild(lockList, "lockScreenDashboardsPanel").visible, "no panel behind a phone's rows");
        }

        function test_phone_stack_stays_under_the_clock() {
            for (var i = 0; i < 4; i++)
                addToast("t" + i);
            tryCompare(sharedModel, "count", 4);
            var one = sharedModel.get(0).notifHeight;
            lockList.availableHeight = 2 * one + lockList.spacing;
            lockList.active = true;
            tryCompare(lockList, "shownRows", 2);
            lockList.availableHeight = Qt.binding(() => lockList.height);
        }

        // 3.0.5: six at most in a panel in the middle, the newest on top,
        // the fade over the bottom once six are shown.
        function test_tablet_panel() {
            prefs.set("notificationStyle", "tablet");
            tryCompare(NotificationLayout, "tabletStyle", true);
            for (var i = 0; i < 7; i++)
                addToast("t" + i);
            tryCompare(sharedModel, "count", 7);
            lockList.active = true;
            tryCompare(lockList, "shownRows", 6);

            var rowsArea = findChild(lockList, "lockScreenDashboardsRows");
            compare(rowsArea.width, lockList.rowWidth);
            fuzzyCompare(rowsArea.y + rowsArea.height / 2, lockList.height / 2, 1, "in the middle");
            compare(rowFromNewest(0).y, 0, "the newest on top");
            verify(rowFromNewest(1).y > rowFromNewest(0).y);
            compare(rowFromNewest(5).opacity, 1, "no fading on the tablet");
            verify(!rowFromNewest(6).visible);
            verify(findChild(lockList, "lockScreenDashboardsPanel").visible);
            verify(findChild(lockList, "lockScreenDashboardsFade").visible);

            // one row fewer: no fade
            ModelSingletons.toastModel.remove(0);
            ModelSingletons.toastModel.remove(0);
            tryCompare(lockList, "shownRows", 5);
            verify(!findChild(lockList, "lockScreenDashboardsFade").visible);
        }

        // A notification's tap would launch its application from behind
        // the lock; a dashboard takes taps only when it asked to.
        function test_taps() {
            addToast("t");
            var plain = addDashboard();
            var clickable = addDashboard({ "LuneOS_clickablewhenlocked": "true" });
            tryCompare(sharedModel, "count", 3);
            lockList.active = true;
            tryVerify(() => isOnLockScreen(plain) && isOnLockScreen(clickable), 2000);

            mouseClick(clickable, clickable.width / 2, clickable.height / 2);
            compare(clickable.presses, 1, "the clickable dashboard takes the tap");
            mouseClick(plain, plain.width / 2, plain.height / 2);
            compare(plain.presses, 0, "the other one does not");

            var toast = rowFromNewest(2);
            mouseClick(toast, toast.width / 2, toast.height / 2);
            compare(launcherInstance.launches, 0, "a notification launches nothing from the lock screen");
        }

        // The notification area's row, still there behind the lock screen,
        // closes a toast when it expires; the lock screen's copy does not
        // do it a second time.
        function test_one_expiry_timer() {
            addToast("t");
            tryCompare(sharedModel, "count", 1);
            // past its banner, to the list
            findChild(area, "bannerPopupArea").popupModel.clear();
            area.state = "open";
            lockList.active = true;
            tryCompare(lockList, "shownRows", 1);
            var lockTimer = findChild(rowFromNewest(0), "expiryTimer");
            // the area's row: a list's delegates are no QObject children of
            // the list, and a Timer is no visual child, so through its item
            var areaTimer = null;
            tryVerify(function() {
                var rows = findChild(area, "openListView").contentItem.children;
                for (var i = 0; i < rows.length; i++) {
                    var item = rows[i].notifItem ? rows[i].notifItem.item : null;
                    if (item)
                        areaTimer = findChild(item, "expiryTimer");
                }
                return areaTimer !== null;
            }, 2000, "the notification area makes its row");
            verify(lockTimer !== null, "the lock screen's row has its timer");
            verify(areaTimer !== null, "the notification area's row has its timer");
            verify(areaTimer.running, "the notification area's runs");
            verify(!lockTimer.running, "the lock screen's does not");
        }

        function lockBanners() {
            return findChild(lockList, "lockScreenBanner").popupModel;
        }

        function areaBanners(a) {
            return findChild(a, "bannerPopupArea").popupModel;
        }

        // Unlocked, the notification area plays it, as before.
        function test_banner_unlocked_is_the_areas() {
            addToast("t");
            tryCompare(sharedModel, "count", 1);
            compare(areaBanners(area).count, 1);
            compare(lockBanners().count, 0);
            areaBanners(area).clear();
        }

        // Locked, the lock screen plays it and the hidden areas do not, so
        // its sound plays once. LockWindow showed BannerAlerts in place of
        // the DashboardAlerts until the banners were done.
        function test_banner_on_the_lock_screen() {
            addToast("old");
            tryCompare(sharedModel, "count", 1);
            areaBanners(area).clear();
            var tablet = createTemporaryObject(tabletArea, root);
            lockList.active = true;
            tryCompare(lockList, "shownRows", 1);
            var rowsArea = findChild(lockList, "lockScreenDashboardsRows");
            verify(rowsArea.visible);

            addToast("new");
            tryCompare(sharedModel, "count", 2);
            compare(lockBanners().count, 1, "the lock screen takes the banner");
            compare(areaBanners(area).count, 0, "the phone's area does not");
            compare(areaBanners(tablet).count, 0, "nor the tablet's");
            verify(lockList.visible);
            verify(lockList.bannerShowing);
            verify(!rowsArea.visible, "the list waits for the banner");
            verify(findChild(lockList, "lockScreenBanner").visible);

            lockBanners().clear();
            verify(rowsArea.visible, "and comes back after it");
            verify(!findChild(lockList, "lockScreenBanner").visible);
        }

        // A light toast is a banner only: with nothing listed it still shows.
        function test_light_banner_alone() {
            lockList.active = true;
            addToast("light one", "light");
            compare(lockBanners().count, 1);
            compare(sharedModel.count, 0);
            verify(lockList.visible);
        }

        // Where the stack ends on a phone, a black rounded strip as wide as
        // the rows; in the middle in a popup panel on a tablet.
        function test_banner_layouts() {
            lockList.active = true;
            addToast("t", "light");
            var banner = findChild(lockList, "lockScreenBanner");
            compare(banner.width, lockList.rowWidth);
            compare(banner.y + banner.height, lockList.height);
            verify(findChild(lockList, "lockScreenBannerStrip").visible);
            verify(!findChild(lockList, "lockScreenBannerPanel").visible);
            lockBanners().clear();

            prefs.set("notificationStyle", "tablet");
            tryCompare(NotificationLayout, "tabletStyle", true);
            addToast("t", "light");
            compare(banner.width, lockList.rowWidth);
            fuzzyCompare(banner.y + banner.height / 2, lockList.height / 2, 1);
            verify(findChild(lockList, "lockScreenBannerPanel").visible);
            verify(!findChild(lockList, "lockScreenBannerStrip").visible);
            verify(!findChild(lockList, "lockScreenDashboardsPanel").visible, "the list's panel waits");
        }

        function test_banner_opens_nothing_from_the_lock_screen() {
            lockList.active = true;
            addToast("t");
            var item = null;
            tryVerify(() => (item = findChild(lockList, "bannerItem")) !== null, 2000);
            wait(600); // slid in
            mouseClick(item, item.width / 2, item.height / 2);
            compare(launcherInstance.launches, 0);
        }

        // Unlocked or on to the passcode mid-banner: it is not replayed.
        function test_banner_goes_with_the_lock_screen() {
            lockList.active = true;
            addToast("t");
            compare(lockBanners().count, 1);
            lockList.active = false;
            compare(lockBanners().count, 0);
            compare(areaBanners(area).count, 0, "not handed on to be played again");
        }

        function test_clickable_when_locked() {
            verify(sharedModel.clickableWhenLocked({ windowProperties: { "LuneOS_clickablewhenlocked": "true" } }));
            verify(!sharedModel.clickableWhenLocked({ windowProperties: { "LuneOS_clickablewhenlocked": "false" } }));
            verify(!sharedModel.clickableWhenLocked({ windowProperties: {} }));
            verify(!sharedModel.clickableWhenLocked(null));
        }
    }
}
