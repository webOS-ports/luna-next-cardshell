import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * A shell that restarts subscribes to notificationmgr again, which hands it
 * the toasts that were on screen, marked "replayed". They go back in the list
 * as they were - grouped, with the LED for them - but with no banner, and so
 * no sound, for something the user has already seen and heard. A toast that
 * comes in after them is a toast as ever.
 *
 * Every case runs on the phone's NotificationArea and the tablet's
 * NotificationAreaTablet.
 */
Item {
    id: root
    width: 320
    height: 480

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
            mergedModel: NotificationsMergedModel {
                objectName: "notificationMergedModel"
                held: windowManager.state === "firstuse"
            }
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
            mergedModel: NotificationsMergedModel {
                objectName: "notificationMergedModel"
                held: windowManager.state === "firstuse"
            }
            maxDashboardWindowHeight: 240
        }
    }

    TestCase {
        name: "ToastReplay"
        when: windowShown

        property int serial: 0

        // A toast as notificationmgr posts it; replayed as it hands one to a
        // new subscriber.
        function addToast(type, title, replayed, groupId) {
            serial++;
            var toast = {
                "message": "message " + serial,
                "title": title,
                "type": type,
                "sourceId": "com.example.app",
                "ownerId": "com.example.app",
                "iconPath": "",
                "timestamp": String(1000 + serial),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "com.example.app" } }
            };
            if (replayed)
                toast.replayed = true;
            if (groupId)
                toast.groupId = groupId;
            ModelSingletons.toastModel.append(toast);
        }

        function init() {
            ModelSingletons.toastModel.clear();
            windowManager.state = "normal";
            windowManager.tapActions = [];
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

        function test_a_replayed_toast_is_listed_without_a_banner_data() { return areas_data(); }
        function test_a_replayed_toast_is_listed_without_a_banner(data) {
            var a = makeArea(data.tablet);
            addToast("standard", "New message", true);

            compare(a.banners.count, 0, "no banner, and so no sound");
            compare(a.model.count, 1);
            compare(a.model.get(0).notifObject.title, "New message");
            compare(a.area.state, "minimized");
            verify(a.area.visible);
            // the mock's preference is off; on, so the toast is what decides
            a.model.notificationLed.blinkNotifications = true;
            a.model.notificationLed.displayOn = false;
            verify(a.model.notificationLed.ledShouldBlink, "still waiting: the LED blinks for it");
        }

        // Each comes back into its group, the newest on top, as before.
        function test_replayed_toasts_go_back_into_their_groups_data() { return areas_data(); }
        function test_replayed_toasts_go_back_into_their_groups(data) {
            var a = makeArea(data.tablet);
            addToast("standard", "first", true, "work");
            addToast("standard", "second", true, "work");
            addToast("standard", "other", true, "home");

            compare(a.banners.count, 0);
            compare(a.model.count, 2);
            compare(a.model.get(0).groupCount, 2);
            compare(a.model.get(0).notifObject.title, "second");
            compare(a.model.get(1).notifObject.title, "other");
        }

        function test_a_new_toast_after_them_gets_its_banner_data() { return areas_data(); }
        function test_a_new_toast_after_them_gets_its_banner(data) {
            var a = makeArea(data.tablet);
            addToast("standard", "old", true);
            compare(a.banners.count, 0);

            addToast("standard", "new", false);
            compare(a.banners.count, 1);
            compare(a.model.count, 1);
            compare(a.model.get(0).groupCount, 2);
            compare(a.model.get(0).notifObject.title, "new");
        }

        // notificationmgr keeps no "light" toast, but one that came anyway is
        // nothing but a banner, and it has had that.
        function test_a_replayed_light_toast_shows_nothing_data() { return areas_data(); }
        function test_a_replayed_light_toast_shows_nothing(data) {
            var a = makeArea(data.tablet);
            addToast("light", "Copied", true);
            compare(a.banners.count, 0);
            compare(a.model.count, 0);
        }

        // Replayed while First Use holds the toasts: listed once it is over,
        // with no banner, as any held sticky toast.
        function test_a_replayed_toast_held_in_first_use_data() { return areas_data(); }
        function test_a_replayed_toast_held_in_first_use(data) {
            windowManager.state = "firstuse";
            var a = makeArea(data.tablet);
            addToast("standard", "System update available", true);
            compare(a.model.count, 0);
            compare(a.model.heldToasts.length, 1);

            windowManager.state = "normal";
            compare(a.model.count, 1);
            compare(a.banners.count, 0);
        }
    }
}
