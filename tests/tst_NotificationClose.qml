import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * Closing one notification in the dashboard list removes that one and no
 * other. The notification's own item is built from a component that lives in
 * the merged model, outside the list's delegate, so it has no model index of
 * its own to remove by; removing by "index" there used to remove row 0 as well.
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

    // the same wiring as the open list's delegate in NotificationArea.qml
    Component {
        id: loaderComponent
        Loader {
            width: 300
            height: 50
            sourceComponent: mergedModel.notificationItemDelegate
            property var loaderNotifObject
            property Item loaderWindow: null
            property QtObject loaderCompositorInstance: null
        }
    }

    TestCase {
        name: "NotificationClose"
        when: windowShown

        function addToast(n) {
            ModelSingletons.toastModel.append({
                "message": "message " + n,
                "title": "title " + n,
                "type": "standard",
                "sourceId": "com.example.app",
                // each in a group of its own, so each is an entry of its own
                "groupId": "group " + n,
                "timestamp": String(1000 + n),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "com.example.app" } }
            });
        }

        function titles() {
            var found = [];
            for (var i = 0; i < mergedModel.count; i++)
                found.push(mergedModel.get(i).notifObject.title);
            return found;
        }

        function init() {
            ModelSingletons.toastModel.clear();
            mergedModel.clear();
            for (var n = 1; n <= 5; n++)
                addToast(n);
            compare(mergedModel.count, 5);
        }

        function closeRow(row) {
            var loader = createTemporaryObject(loaderComponent, root,
                    { "loaderNotifObject": mergedModel.get(row).notifObject });
            tryVerify(function() { return loader.status === Loader.Ready; });
            loader.item.closed();
        }

        function test_closeOne_data() {
            return [
                { tag: "first", row: 0, left: ["title 2", "title 3", "title 4", "title 5"] },
                { tag: "middle", row: 2, left: ["title 1", "title 2", "title 4", "title 5"] },
                { tag: "last", row: 4, left: ["title 1", "title 2", "title 3", "title 4"] }
            ];
        }

        function test_closeOne(data) {
            closeRow(data.row);
            compare(titles(), data.left);
            compare(ModelSingletons.toastModel.count, 4);
        }

        // notificationmgr may withdraw the toast before or after the shell
        // drops the row; either way only that one row goes
        function test_toastWithdrawnFirst() {
            ModelSingletons.toastModel.remove(4);
            compare(titles(), ["title 1", "title 2", "title 3", "title 4"]);
        }
    }
}
