import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * The minimized notification bar shows one icon per application. Messaging
 * posts a toast per message, and each used to get an icon of its own, so a
 * dozen messages made a row of a dozen identical icons; legacy showed one.
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
                         (model.appKey === "" || mergedModel.firstIndexOfApp(model.appKey) === index)
            }
        }
    }

    TestCase {
        name: "NotificationIconPerApp"
        when: windowShown

        property int stamp: 0

        function addToast(sourceId) {
            stamp++;
            ModelSingletons.toastModel.append({
                "message": "message " + stamp,
                "title": "title " + stamp,
                "type": "standard",
                "sourceId": sourceId,
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
