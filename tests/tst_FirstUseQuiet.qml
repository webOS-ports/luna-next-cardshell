import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

import "../qml/Notifications"

/*
 * While First Use runs (the window manager in "firstuse"), an application's
 * notifications are held: no banner, no entry in the list, no LED, nothing to
 * tap - tapping one launched its application and took the user out of First
 * Use. Once the state is "normal" they come in: a sticky toast in the list, a
 * light one as its banner. A toast withdrawn meanwhile does not come back.
 *
 * An application's popup alert and a com.webos.notification alert wait too,
 * but the incoming call and the alarm, which the lock screen also lets
 * through, still come up.
 *
 * Every notification-area case runs on the phone's NotificationArea and the
 * tablet's NotificationAreaTablet.
 */
Item {
    id: root
    width: 320
    height: 480

    // WindowManager: its state, and the tap-action stack the areas use
    Item {
        id: windowManager
        state: "firstuse"
        states: [ State { name: "firstuse" }, State { name: "normal" } ]
        property var tapActions: []
        function addTapAction(id, fct, data) {
            tapActions.push({ "id": id, "fct": fct, "data": data });
        }
        function removeTapAction(id) {
            tapActions = tapActions.filter(function(a) { return a.id !== id; });
        }
    }

    // What the notification's own item launches through (CardsArea's launcher)
    Item {
        id: launcherInstance
        property var launched: []
        function launchApplication(id, params, successCB) {
            launched = launched.concat([id]);
        }
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
            compositorInstance: QtObject {
                property ListModel surfaceModel: ListModel {}
            }
            windowManagerInstance: windowManager
            maxDashboardWindowHeight: 240
        }
    }

    // the same wiring as the open list's delegate in NotificationArea.qml
    Component {
        id: itemLoader
        Loader {
            width: 300
            height: 50
            property var loaderNotifObject
            property Item loaderWindow: null
            property QtObject loaderCompositorInstance: null
        }
    }

    Compositor { id: compositor }

    Component {
        id: alertWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_SYSTEM_UI"
            property var windowProperties: ({})
            function changeSize(size) {}
        }
    }

    Component {
        id: alertsArea
        AlertWindowsArea {
            width: 480
            maxAlertHeight: 600
            compositorInstance: compositor
            appAlertsHeld: windowManager.state === "firstuse"
        }
    }

    Component {
        id: notificationAlerts
        NotificationAlertsArea {
            width: 300
            held: windowManager.state === "firstuse"
        }
    }

    Component {
        id: fakePlayer
        QtObject {
            property string path
            property string sink
            property bool looping
            property int durationMs: -1
            property string playbackId: ""
            property bool heldByAudiod: false
            signal finished()
            signal limitReached()
            function playLocally() {}
            function startLimit(ms) {}
            function stop() { finished(); }
            function finish() { finished(); }
        }
    }

    TestCase {
        name: "FirstUseQuiet"
        when: windowShown

        property int serial: 0

        function addToast(type, title) {
            serial++;
            ModelSingletons.toastModel.append({
                "message": "message " + serial,
                "title": title,
                "type": type,
                "sourceId": "com.example.app",
                "ownerId": "com.example.app",
                "iconPath": "",
                "timestamp": String(1000 + serial),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "org.webosports.app.settings" } }
            });
        }

        function init() {
            ModelSingletons.toastModel.clear();
            windowManager.state = "firstuse";
            windowManager.tapActions = [];
            launcherInstance.launched = [];
        }

        function cleanup() {
            while (compositor.surfaceModel.count > 0)
                compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        }

        function makeArea(tablet) {
            var area = createTemporaryObject(tablet ? tabletArea : phoneArea, root);
            verify(area !== null);
            return {
                area: area,
                model: findChild(area, "notificationMergedModel"),
                banners: findChild(area, "bannerPopupArea").popupModel
            };
        }

        function areas_data() {
            return [ { tag: "phone", tablet: false }, { tag: "tablet", tablet: true } ];
        }

        function test_a_toast_is_held_in_first_use_data() { return areas_data(); }
        function test_a_toast_is_held_in_first_use(data) {
            var a = makeArea(data.tablet);
            addToast("standard", "System update available");

            compare(a.area.state, "held");
            verify(!a.area.visible);
            verify(!a.area.enabled);
            if (!data.tablet)
                compare(a.area.height, 0);
            compare(a.banners.count, 0);
            compare(a.model.count, 0);
            compare(a.model.heldToasts.length, 1);
            // the mock's preference is off; on, so only the hold keeps it dark
            a.model.notificationLed.blinkNotifications = true;
            a.model.notificationLed.displayOn = false;
            verify(!a.model.notificationLed.ledShouldBlink, "no LED for a held toast");
            compare(windowManager.tapActions.length, 0);
        }

        function test_it_comes_in_once_first_use_is_over_data() { return areas_data(); }
        function test_it_comes_in_once_first_use_is_over(data) {
            var a = makeArea(data.tablet);
            addToast("standard", "System update available");
            a.model.notificationLed.blinkNotifications = true;
            a.model.notificationLed.displayOn = false;
            verify(!a.model.notificationLed.ledShouldBlink);

            windowManager.state = "normal";

            compare(a.model.heldToasts.length, 0);
            compare(a.model.count, 1);
            compare(a.model.get(0).notifObject.title, "System update available");
            // in the list, without a banner of its own
            compare(a.banners.count, 0);
            compare(a.area.state, "minimized");
            verify(a.area.visible);
            verify(a.area.enabled);
            verify(a.model.notificationLed.ledShouldBlink, "the LED blinks for it now");

            // and a toast after First Use is a toast as ever: banner and list
            addToast("standard", "later");
            compare(a.banners.count, 1);
            // the same app's: it joins that entry, and is shown on top
            compare(a.model.count, 1);
            compare(a.model.get(0).groupCount, 2);
            compare(a.model.get(0).notifObject.title, "later");
        }

        function test_a_light_toast_gets_its_banner_after_data() { return areas_data(); }
        function test_a_light_toast_gets_its_banner_after(data) {
            var a = makeArea(data.tablet);
            addToast("light", "Copied");
            compare(a.banners.count, 0);

            windowManager.state = "normal";
            compare(a.banners.count, 1);
            compare(a.model.count, 0);
        }

        function test_a_toast_withdrawn_meanwhile_stays_gone_data() { return areas_data(); }
        function test_a_toast_withdrawn_meanwhile_stays_gone(data) {
            var a = makeArea(data.tablet);
            addToast("standard", "first");
            addToast("standard", "second");
            ModelSingletons.toastModel.remove(0);
            compare(a.model.heldToasts.length, 1);

            windowManager.state = "normal";
            compare(a.model.count, 1);
            compare(a.model.get(0).notifObject.title, "second");
        }

        // The notification's own item is the one place a toast launches its
        // application; it must not, even if something got it on screen.
        function test_a_tap_launches_nothing_in_first_use() {
            var a = makeArea(false);
            var loader = createTemporaryObject(itemLoader, root, {
                "loaderNotifObject": {
                    "title": "System update available", "message": "", "iconPath": "",
                    "sourceId": "org.webosports.service.update", "timestamp": "1",
                    "schedule": { "expire": Date.now() / 1000 + 3600 },
                    "action": { "launchParams": { "id": "org.webosports.app.settings",
                                                  "params": { "needUpdate": true } } }
                }
            });
            loader.sourceComponent = a.model.notificationItemDelegate;
            tryVerify(function() { return loader.status === Loader.Ready; });

            mouseClick(loader.item);
            compare(launcherInstance.launched, []);

            windowManager.state = "normal";
            mouseClick(loader.item);
            compare(launcherInstance.launched, ["org.webosports.app.settings"]);
        }

        function openAlert(props) {
            var all = { "LuneOS_window": "popupalert" };
            for (var k in props)
                all[k] = props[k];
            var window = alertWindow.createObject(compositor, { height: 100, windowProperties: all });
            compositor.surfaceModel.append({ obj: window });
            return window;
        }

        function shown(window) {
            return window.parent !== null && window.parent.visible;
        }

        function test_an_app_alert_waits_but_a_call_and_the_alarm_do_not() {
            var area = createTemporaryObject(alertsArea, root);
            var sounds = findChild(area, "soundNotifications");
            sounds.fileExists = function(path) { return true; };
            sounds.callService = function(url, request, onReply) {};
            sounds.playerComponent = fakePlayer;

            var message = openAlert({ "LuneOS_soundclass": "alerts" });
            compare(area.maxHeight, 0);
            verify(!shown(message));
            compare(sounds.players.length, 0, "no sound for an alert that waits");

            var call = openAlert({ "LuneOS_overLockScreen": "true" });
            var alarm = openAlert({ "LuneOS_clickablewhenlocked": "true",
                                    "LuneOS_soundclass": "alarm" });
            tryVerify(function() { return shown(call); });
            tryVerify(function() { return shown(alarm); });
            compare(sounds.players.length, 1, "the alarm sounds");
            verify(!shown(message));

            // A tap outside the alarm closes the alarm, not what was never seen
            area.closeAll();
            compare(compositor.surfaceModel.count, 2);
            verify(compositor.surfaceModel.get(0).obj === message);

            windowManager.state = "normal";
            tryVerify(function() { return shown(message); });
            compare(area.maxHeight, 100);
            compare(sounds.players.length, 1, "it sounds now it is up");
        }

        function test_an_app_sound_is_turned_down_in_first_use() {
            var area = createTemporaryObject(alertsArea, root);
            var sounds = findChild(area, "soundNotifications");
            var reply = JSON.parse(sounds.handlePlay({ payload: '{"soundClass": "notifications"}' }));
            compare(reply.returnValue, false);
            compare(sounds.players.length, 0);
        }

        function test_a_notification_alert_waits() {
            var alerts = createTemporaryObject(notificationAlerts, root);
            alerts.handleAlertMessage({
                "timestamp": "1",
                "alertInfo": { "alertId": "a1", "title": "Media access", "message": "?",
                               "modal": false, "buttons": [] }
            });
            verify(!alerts.showing);
            verify(!alerts.visible);
            // a tap outside does not answer a question nobody saw
            alerts.dismiss();

            windowManager.state = "normal";
            verify(alerts.showing);
            compare(alerts.currentAlert.title, "Media access");
        }
    }
}
