import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * The minimized notification bar shows one icon per application and icon.
 * Messaging posts a toast per message, and each used to get an icon of its
 * own, so a dozen messages made a row of a dozen identical icons; legacy
 * showed one. Its protocols are stacks of their own, each with its account's
 * icon, and those show once each.
 */
Item {
    id: root
    width: 320
    height: 480

    // what NotificationsMergedModel resolves from the shell around it
    property int dashboardCardFixedHeight: 50
    property QtObject compositorInstance: QtObject {
        property ListModel surfaceModel: ListModel {}
    }
    Item { id: notificationArea }

    NotificationsMergedModel {
        id: mergedModel
    }

    // The minimized bar's Repeater, with the same visibility rule as the
    // delegates in NotificationArea.qml and NotificationAreaTablet.qml.
    Row {
        id: iconRow
        Repeater {
            id: iconRepeater
            model: mergedModel
            delegate: Item {
                width: 10
                height: 10
                visible: mergedModel.count > 0 &&
                         (model.appKey === "" || mergedModel.firstIndexOfIcon(model.iconKey) === index)
            }
        }
    }

    TestCase {
        name: "NotificationIconPerApp"
        when: windowShown

        property int stamp: 0

        function addToast(sourceId, iconUrl, groupId) {
            stamp++;
            ModelSingletons.toastModel.append({
                "iconUrl": iconUrl || "",
                "message": "message " + stamp,
                "title": "title " + stamp,
                "type": "standard",
                "sourceId": sourceId,
                // a group per toast, as an app with a group per conversation
                // or account would have: several entries of one app
                "groupId": groupId || ("group " + stamp),
                "timestamp": String(1000 + stamp),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": sourceId } }
            });
        }

        function shownIcons() {
            var n = 0;
            for (var i = 0; i < iconRepeater.count; i++)
                if (iconRepeater.itemAt(i).visible) n++;
            return n;
        }

        function init() {
            ModelSingletons.toastModel.clear();
            mergedModel.clear();
        }

        function test_entriesCarryTheirApp() {
            addToast("org.webosports.messaging");
            compare(mergedModel.count, 1);
            compare(mergedModel.get(0).appKey, "org.webosports.messaging");
        }

        function test_oneIconForManyToastsOfOneApp() {
            for (var n = 0; n < 20; n++)
                addToast("org.webosports.messaging");
            compare(mergedModel.count, 20);
            compare(shownIcons(), 1);
        }

        function test_oneIconPerApp() {
            addToast("org.webosports.messaging");
            addToast("org.webosports.app.phone");
            addToast("org.webosports.messaging");
            addToast("org.webosports.app.phone");
            addToast("com.example.mail");
            compare(mergedModel.count, 5);
            compare(shownIcons(), 3);
        }

        function test_oneIconPerProtocolOfOneApp() {
            var sms = "file:///usr/palm/public/accounts/com.palm.palmprofile/images/sms-48x48.png";
            var tg = "file:///usr/palm/public/accounts/com.palm.telegram/images/telegram-48x48.png";
            addToast("org.webosports.app.messaging", sms, "sms");
            addToast("org.webosports.app.messaging", tg, "type_telegram");
            addToast("org.webosports.app.messaging", sms, "sms");
            addToast("org.webosports.app.messaging", tg, "type_telegram");
            compare(mergedModel.count, 2, "a stack a protocol");
            compare(shownIcons(), 2);
            // groups that share an icon, as an app's accounts may: still one
            addToast("com.example.mail", "", "work");
            addToast("com.example.mail", "", "home");
            compare(mergedModel.count, 4);
            compare(shownIcons(), 3);
        }

        function test_theSameIconInAnotherAppIsAnotherIcon() {
            addToast("com.example.one", "file:///icon.png");
            addToast("com.example.two", "file:///icon.png");
            compare(shownIcons(), 2);
        }

        function test_nextEntryTakesOverTheIcon() {
            addToast("org.webosports.messaging");
            addToast("org.webosports.messaging");
            mergedModel.remove(0);
            compare(mergedModel.count, 1);
            verify(iconRepeater.itemAt(0).visible);
            compare(shownIcons(), 1);
        }
    }
}
