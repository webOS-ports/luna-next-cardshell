import QtQuick 2.0
import QtTest 1.0
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0
import LuneOS.System 1.0

import "../qml/Notifications"
import "../qml/Utils"

/*
 * A banner opens the app its notification is for when tapped, as legacy
 * webOS's banners did and as the notification's entry in the list does. The
 * banner let a tap through to nothing: with an app in front, the only way to
 * a new message's chat was to open the list first. A tapped banner goes; the
 * toast stays listed. A banner with nothing to open, and any banner during
 * First Use, launches nothing.
 */
Item {
    id: root
    width: 480
    height: 640

    Item {
        id: windowManager
        state: "normal"
        states: [ State { name: "firstuse" }, State { name: "normal" } ]
        function addTapAction(id, fct, data) {}
        function removeTapAction(id) {}
    }

    // What a tapped banner launches through.
    Item {
        id: launcherInstance
        property var launched: []
        function launchApplication(id, params, successCB) {
            launched = launched.concat([{ "id": id, "params": params }]);
        }
    }

    Compositor { id: compositor }

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

    TestCase {
        name: "BannerTap"
        when: windowShown

        property int serial: 0

        // A toast as Messaging raises one for a new message: tapping it opens the chat.
        function addToast(action) {
            serial++;
            var toast = {
                "message": "message " + serial,
                "title": "",
                "type": "standard",
                "sourceId": "org.webosports.app.messaging",
                "ownerId": "org.webosports.app.messaging",
                "iconPath": "",
                "timestamp": String(2000 + serial),
                "schedule": { "expire": Date.now() / 1000 + 3600 }
            };
            if (action)
                toast.action = action;
            ModelSingletons.toastModel.append(toast);
        }

        function chatAction(threadId) {
            return { "launchParams": { "id": "org.webosports.app.messaging", "params": { "threadId": threadId } } };
        }

        function banners(area) {
            return findChild(area, "bannerPopupArea").popupModel;
        }

        // The banner on screen once it has slid in.
        function shownBanner(area) {
            var popup = findChild(area, "bannerPopupArea");
            var item = null;
            tryVerify(function () {
                item = findChild(popup, "bannerItem");
                return item !== null && item.y === 0 && item.width > 0;
            }, 3000, "the banner slid in");
            return item;
        }

        function init() {
            launcherInstance.launched = [];
            windowManager.state = "normal";
        }

        function cleanup() {
            ModelSingletons.toastModel.clear();
            tryCompare(sharedModel, "count", 0);
        }

        function test_tapOpensTheChat_data() {
            return [ { tag: "phone", area: phoneArea }, { tag: "tablet", area: tabletArea } ];
        }

        function test_tapOpensTheChat(data) {
            var area = createTemporaryObject(data.area, root);
            addToast(chatAction("thread-1"));
            tryCompare(banners(area), "count", 1);
            var banner = shownBanner(area);
            mouseClick(banner, banner.width / 2, banner.height / 4);
            compare(launcherInstance.launched.length, 1, "one launch for the tap");
            compare(launcherInstance.launched[0].id, "org.webosports.app.messaging");
            compare(launcherInstance.launched[0].params.threadId, "thread-1", "the toast's own params");
            tryCompare(banners(area), "count", 0, 1000, "the tapped banner goes");
            compare(sharedModel.count, 1, "the toast stays listed");
        }

        function test_nothingToOpen() {
            var area = createTemporaryObject(phoneArea, root);
            addToast(null);
            tryCompare(banners(area), "count", 1);
            var banner = shownBanner(area);
            mouseClick(banner, banner.width / 2, banner.height / 4);
            compare(launcherInstance.launched.length, 0);
            compare(banners(area).count, 1, "it scrolls on as before");
        }

        // First Use clears the banners (NotificationArea's onHeldChanged), and
        // what a banner would launch through launches nothing while it holds.
        function test_notDuringFirstUse() {
            var area = createTemporaryObject(phoneArea, root);
            addToast(chatAction("thread-2"));
            tryCompare(banners(area), "count", 1);
            windowManager.state = "firstuse";
            tryCompare(banners(area), "count", 0, 1000, "the banner is cleared");
            verify(!sharedModel.launchFromNotification({ "action": chatAction("thread-2") }));
            compare(launcherInstance.launched.length, 0);
            windowManager.state = "normal";
            verify(sharedModel.launchFromNotification({ "action": chatAction("thread-2") }));
            compare(launcherInstance.launched.length, 1);
        }
    }
}
