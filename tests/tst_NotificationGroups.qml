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

    // What a tapped entry launches through; it reports success, as the
    // shell's launcher does once the app is up.
    Item {
        id: launcherInstance
        property var launched: []
        function launchApplication(id, params, successCB) {
            launched = launched.concat([id]);
            if (successCB)
                successCB();
        }
    }

    NotificationsMergedModel {
        id: mergedModel
    }

    // A model and a view of their own, new for the test: a model takes the
    // roles its views follow from the rows it has first, so the shared one
    // above, which other tests fill with toasts first, would not show it.
    Component {
        id: freshList
        Item {
            property alias model: freshModel
            property alias view: freshView
            NotificationsMergedModel { id: freshModel }
            // each row's delegate reads the roles, as the areas' delegates
            // read groupCount
            Repeater {
                id: freshView
                model: freshModel
                delegate: Item {
                    property int shownCount: typeof groupCount !== 'undefined' && groupCount ? groupCount : 1
                    property var shownBelow: typeof belowNotifObject !== 'undefined' ? belowNotifObject : null
                }
            }
        }
    }

    // A dashboard window, as listDashboardsModel takes it from the surfaces.
    Component {
        id: dashboardWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_FLOATING"
            property string appId: "com.palm.systemui"
            property var windowProperties: ({})
        }
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
                found.push(e.notifType === "dashboard" ? "dashboard" : e.notifObject.title + " x" + e.groupCount);
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
            compositorInstance.surfaceModel.clear();
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

        // A dashboard listed before any toast (USB's, at boot) gave the
        // model its first row; the roles that row did not have were never
        // followed by the views, and every group showed a single toast.
        function test_countAfterADashboardIsListedFirst() {
            var list = createTemporaryObject(freshList, root);
            var window = createTemporaryObject(dashboardWindow, root);
            compositorInstance.surfaceModel.append({"obj": window});
            compare(list.model.count, 1);
            compare(list.model.get(0).notifType, "dashboard");

            addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            compare(list.model.get(1).groupCount, 3);
            compare(list.view.count, 2);
            compare(list.view.itemAt(1).shownCount, 3, "the view sees the group's count");
            compare(list.view.itemAt(0).shownCount, 1, "a dashboard is one entry");
        }

        // What a swipe of the top layer uncovers: the toast under the newest,
        // kept up as toasts come and go, and none for a single toast.
        function below(row) {
            var b = mergedModel.get(row).belowNotifObject;
            return b ? b.title : null;
        }
        function test_entryKnowsTheToastUnderItsNewest() {
            var first = addToast("org.webosports.app.messaging");
            compare(below(0), null, "nothing under a single toast");
            var second = addToast("org.webosports.app.messaging");
            compare(below(0), first);
            addToast("org.webosports.app.messaging");
            compare(below(0), second);

            var loader = showRow(0);
            loader.item.closed();                   // the top layer swiped away
            compare(below(0), first);
            loader.item.closed();
            compare(below(0), null);

            var third = addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            ModelSingletons.toastModel.remove(ModelSingletons.toastModel.count - 2);   // the one under
            compare(below(0), first, "a withdrawn toast under the top one is no longer shown");
        }

        // The roles a view follows are the first row's: a dashboard listed
        // first must already have this one.
        function test_belowAfterADashboardIsListedFirst() {
            var list = createTemporaryObject(freshList, root);
            var window = createTemporaryObject(dashboardWindow, root);
            compositorInstance.surfaceModel.append({"obj": window});
            var first = addToast("org.webosports.app.messaging");
            addToast("org.webosports.app.messaging");
            var shown = list.view.itemAt(1).shownBelow;
            verify(shown, "the view sees the toast under the newest");
            compare(shown.title, first);
        }

        // An Enyo 1 dashboard (Email's) swipes its own layers once it has
        // more than one, and says how many in LuneOS_dashLayers: the shell's
        // swipe then keeps out of it, and comes back for the last layer. The
        // page changes the count as layers come and go, so it is followed.
        Component {
            id: swipeWatcher
            QtObject {
                property Item window
                property bool pageSwipes: mergedModel.swipesOwnLayers(window)
            }
        }
        function test_enyoDashboardWithLayersSwipesThemItself() {
            var window = createTemporaryObject(dashboardWindow, root);
            var watcher = createTemporaryObject(swipeWatcher, root, { "window": window });
            verify(!watcher.pageSwipes, "no count: the shell's swipe");
            window.windowProperties = { "LuneOS_dashLayers": "3" };
            verify(watcher.pageSwipes, "three layers: the page's");
            window.windowProperties = { "LuneOS_dashLayers": "1" };
            verify(!watcher.pageSwipes, "the last one: the shell's again");
            window.windowProperties = { "LuneOS_dashLayers": "2", "LuneOS_dashheight": "60" };
            verify(watcher.pageSwipes);
            window.windowProperties = { "LuneOS_dashLayers": "many" };
            verify(!watcher.pageSwipes, "not a number: the shell's");
            verify(!mergedModel.swipesOwnLayers(null), "a toast has no window");
        }

        // A tap opens the app and leaves the entry, all its layers, listed:
        // on legacy webOS a dashboard went when it was slid away, or when its
        // app closed it, never for a tap.
        function test_tapLaunchesAndKeepsTheEntry() {
            launcherInstance.launched = [];
            addToast("org.webosports.app.messaging");
            var newest = addToast("org.webosports.app.messaging");
            var loader = showRow(0);
            mouseClick(loader.item);
            compare(launcherInstance.launched, ["org.webosports.app.messaging"]);
            wait(50);
            compare(entries(), [newest + " x2"], "nothing closed");
        }

        // notificationmgr can take several toasts away in one go: every one
        // of them leaves its group. Only the last was taken out, and the
        // others stayed in their groups as rows that were no longer there -
        // an entry with no title, no text and no count.
        function test_toastsWithdrawnTogetherAllLeave() {
            addToast("org.webosports.app.testr", "a");
            addToast("org.webosports.app.testr", "a");
            var keptA = addToast("org.webosports.app.testr", "a");
            var firstB = addToast("org.webosports.app.testr", "b");
            addToast("org.webosports.app.testr", "b");
            ModelSingletons.toastModel.remove(1, 3);   // a2, a3, b1
            compare(entries(), ["title " + (stamp - 4) + " x1", "title " + stamp + " x1"]);
            compare(mergedModel.get(0).belowNotifObject, null);
        }

        // and can hand several over at once, as when the shell starts with
        // toasts already waiting: each one is listed.
        function test_toastsAddedTogetherAreAllListed() {
            var batch = [];
            for (var i = 0; i < 3; i++) {
                stamp++;
                batch.push({ "message": "message " + stamp, "title": "title " + stamp, "type": "standard",
                             "sourceId": "org.webosports.app.testr", "timestamp": String(1000 + stamp),
                             "schedule": { "expire": Date.now() / 1000 + 3600 },
                             "action": { "launchParams": { "id": "org.webosports.app.testr" } } });
            }
            ModelSingletons.toastModel.append(batch);
            compare(entries(), ["title " + stamp + " x3"]);
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
