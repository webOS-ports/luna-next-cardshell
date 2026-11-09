import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0

import "../qml/Notifications"

/*
 * Toasts are listed in groups, as legacy webOS listed dashboards: an app's
 * toasts with the same groupId (or with none) make one entry, which shows the
 * newest and badges how many there are. Closing the entry's toast, or
 * notificationmgr withdrawing any of them, leaves the rest listed.
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
            property int loaderGroupCount: 1
            property Item loaderWindow: null
            property QtObject loaderCompositorInstance: null
        }
    }

    TestCase {
        name: "NotificationGroups"
        when: windowShown

        property int stamp: 0

        function addToast(sourceId, groupId, type) {
            stamp++;
            var toast = {
                "message": "message " + stamp,
                "title": "title " + stamp,
                "type": type || "standard",
                "sourceId": sourceId,
                "timestamp": String(1000 + stamp),
                "schedule": { "expire": Date.now() / 1000 + 3600 },
                "action": { "launchParams": { "id": sourceId } }
            };
            if (groupId !== undefined)
                toast.groupId = groupId;
            ModelSingletons.toastModel.append(toast);
            return "title " + stamp;
        }

        function entries() {
            var found = [];
            for (var i = 0; i < mergedModel.count; i++) {
                var e = mergedModel.get(i);
                found.push(e.notifObject.title + " x" + e.groupCount);
            }
            return found;
        }

        // An entry's item, as the list shows it, kept in step with the model
        // as the areas' delegates keep it.
        function showRow(row) {
            var loader = createTemporaryObject(loaderComponent, root, {
                "loaderNotifObject": Qt.binding(function() { return mergedModel.count > row ? mergedModel.get(row).notifObject : null; }),
                "loaderGroupCount": Qt.binding(function() { return mergedModel.count > row ? mergedModel.get(row).groupCount : 1; })
            });
            tryVerify(function() { return loader.status === Loader.Ready; });
            return loader;
        }

        function findBadge(node) {
            for (var i = 0; i < node.children.length; i++) {
                var child = node.children[i];
                if (child.hasOwnProperty("count") && child.hasOwnProperty("radius"))
                    return child;
                var inner = findBadge(child);
                if (inner)
                    return inner;
            }
            return null;
        }

        function init() {
            ModelSingletons.toastModel.clear();
            mergedModel.clear();
        }

        function test_oneEntryPerAppWithoutGroupId() {
            addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            var newest = addToast("org.webosports.app.messaging");
            compare(entries(), [newest + " x3"]);
        }

        function test_oneEntryPerGroupId() {
            var work = addToast("com.palm.app.email", "work account");
            var home = addToast("com.palm.app.email", "home account");
            var work2 = addToast("com.palm.app.email", "work account");
            compare(entries(), [work2 + " x2", home + " x1"]);
        }

        function test_appsDoNotShareGroups() {
            var a = addToast("com.example.one", "same");
            var b = addToast("com.example.two", "same");
            compare(entries(), [a + " x1", b + " x1"]);
        }

        function test_lightToastsAreNotListed() {
            var kept = addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging", undefined, "light");
            compare(entries(), [kept + " x1"]);
        }

        function test_closingTheEntryClosesOnlyItsNewest() {
            var first = addToast("org.webosports.app.messaging");
            var second = addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            var loader = showRow(0);

            loader.item.closed();
            compare(entries(), [second + " x2"]);
            compare(loader.item.title, second, "the entry shows the next toast");
            compare(loader.item.count, 2);

            loader.item.closed();
            compare(entries(), [first + " x1"]);
            compare(loader.item.title, first);

            loader.item.closed();
            compare(mergedModel.count, 0);
        }

        function test_withdrawnToastLeavesTheRest() {
            addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            var newest = addToast("org.webosports.app.messaging");

            ModelSingletons.toastModel.remove(1);   // the middle one
            compare(entries(), [newest + " x2"]);

            ModelSingletons.toastModel.remove(1);   // the newest
            compare(entries(), ["title " + (stamp - 2) + " x1"]);

            ModelSingletons.toastModel.remove(0);
            compare(mergedModel.count, 0);
        }

        function test_newToastTakesOverTheShownEntry() {
            addToast("org.webosports.app.messaging");
            var loader = showRow(0);
            compare(loader.item.count, 1);

            var newest = addToast("org.webosports.app.messaging");
            compare(loader.item.title, newest);
            compare(loader.item.count, 2);
        }

        function test_badgeOnlyForMoreThanOne() {
            addToast("org.webosports.app.messaging");
            var loader = showRow(0);
            var badge = findBadge(loader.item);
            verify(badge, "the item has a badge");
            verify(!badge.visible, "no badge for a single toast");

            addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            verify(badge.visible, "a badge for three");
            compare(badge.count, 3);
        }

        function test_entryStaysWhereItWas() {
            var mail = addToast("com.palm.app.email");
            addToast("org.webosports.app.messaging");
            var messages = addToast("org.webosports.app.messaging");
            var mail2 = addToast("com.palm.app.email");
            compare(entries(), [mail2 + " x2", messages + " x2"]);
        }
    }
}
