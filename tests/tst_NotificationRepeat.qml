import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * A toast that repeats the last one (same sourceId, message and type) is not
 * appended by luna-surfacemanager's NotificationService: it overwrites that
 * row in place with set(), which carries the new toast's timestamp and emits
 * no rowsInserted or rowsAboutToBeRemoved. Telegram posts "Message from ...
 * has been deleted" like that, three times over, when a sender deletes a
 * message.
 */
Item {
    id: root
    width: 320
    height: 480

    property int dashboardCardFixedHeight: 50
    property QtObject compositorInstance: QtObject {
        property ListModel surfaceModel: ListModel {}
    }
    Item { id: notificationArea }

    NotificationsMergedModel {
        id: mergedModel
    }

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
        name: "NotificationRepeat"
        when: windowShown

        function toast(ts) {
            return {
                "message": "Message from 04:44:12 has been deleted",
                "title": " ",
                "type": "standard",
                "sourceId": "org.webosports.app.messaging",
                "timestamp": String(ts),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": "org.webosports.app.messaging" } }
            };
        }

        function closeRow(row) {
            var loader = createTemporaryObject(loaderComponent, root,
                    { "loaderNotifObject": mergedModel.get(row).notifObject });
            tryVerify(function() { return loader.status === Loader.Ready; });
            loader.item.closed();
        }

        function other(ts) {
            var t = toast(ts);
            t.message = "hello " + ts;
            t.title = "Ann";
            // another conversation: an entry of its own
            t.groupId = "chat with Ann";
            return t;
        }

        // NotificationService.parseModelData, as luna-surfacemanager has it
        function post(d) {
            var m = ModelSingletons.toastModel;
            for (var i = 0; i < m.count; i++) {
                var e = m.get(i);
                if (d.sourceId === e.sourceId && d.message === e.message && d.type === e.type) {
                    if (i === m.count - 1) { m.set(i, d); } else { m.append(d); m.remove(i); }
                    return;
                }
            }
            m.append(d);
        }

        function entries() {
            var out = [];
            for (var i = 0; i < mergedModel.count; i++) {
                var o = mergedModel.get(i).notifObject;
                out.push(o ? (o.message + "@" + o.timestamp) : "null");
            }
            return out;
        }

        function test_repeatAfterAnother_data() {
            return [
                { tag: "close newest first", order: "desc" },
                { tag: "close oldest first", order: "asc" }
            ];
        }

        function test_repeatAfterAnother(data) {
            ModelSingletons.toastModel.clear();
            mergedModel.clear();
            post(toast(1001));     // the notice
            post(other(1002));     // a message from another chat
            post(toast(1003));     // the notice again: append + remove
            post(toast(1004));     // and again: now the last row, set()
            console.log("toasts: " + ModelSingletons.toastModel.count + " entries: " + JSON.stringify(entries()));
            var guard = 0;
            while (mergedModel.count > 0 && guard++ < 5) {
                closeRow(data.order === "desc" ? mergedModel.count - 1 : 0);
                console.log("after close: " + JSON.stringify(entries()));
            }
            compare(mergedModel.count, 0, "entries left: " + JSON.stringify(entries()));
        }

        // As on the phone: the list item exists before the repeat comes in.
        function test_repeatWhileItemShown() {
            ModelSingletons.toastModel.clear();
            mergedModel.clear();
            post(other(1000));     // the message itself
            post(toast(1001));     // the notice
            var loader = createTemporaryObject(loaderComponent, root,
                    { "loaderNotifObject": mergedModel.get(1).notifObject });
            tryVerify(function() { return loader.status === Loader.Ready; });
            post(toast(1002));     // the notice again: set() on the last row
            loader.item.closed();
            compare(entries(), ["hello 1000@1000"], "the notice stayed after it was swiped away");
            compare(ModelSingletons.toastModel.count, 1);
        }

        function test_repeatedToastCanBeClosed() {
            ModelSingletons.toastModel.clear();
            mergedModel.clear();
            ModelSingletons.toastModel.append(toast(1001));
            compare(mergedModel.count, 1);
            // what NotificationService.parseModelData does with the repeat
            ModelSingletons.toastModel.set(0, toast(1002));
            compare(mergedModel.count, 1);
            console.log("entry timestamp after set: " + mergedModel.get(0).notifObject.timestamp);
            closeRow(0);
            compare(mergedModel.count, 0, "the entry stayed in the list after it was closed");
        }
    }
}
