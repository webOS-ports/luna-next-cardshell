/*
 * Copyright (C) 2014-2016 Christophe Chapuis <chris.chapuis@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import QtQml.Models 2.1

import WebOSCoreCompositor 1.0 

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import LuneOS.Service 1.0

import "../Utils"

ListModel {
    id: mergedModel
    dynamicRoles: true

    signal addBannerNotification(var notif);
    signal removeBannerNotification(var notif);

    function getToastIdFromNotif(notifObject) {
        return notifObject.sourceId+"-"+notifObject.timestamp;
    }

    /*
     * The minimized bar shows one icon per application, however many entries
     * it has. Legacy drew an icon per dashboard window, and Messaging kept
     * every new message in a single dashboard, so it was one icon there; here
     * Messaging posts one notificationmgr toast per message, and a busy
     * evening became a row of identical icons. Tapping the icon still opens
     * the list with every entry in it.
     */
    function firstIndexOfApp(appKey) {
        for( var i=0; i<mergedModel.count; ++i ) {
            if( mergedModel.get(i).appKey === appKey )
                return i;
        }
        return -1;
    }

    property IconPathServices iconPathServices: IconPathServices {}
    property NotificationService notificationService: NotificationService {}

    /*
     * Set during First Use. A toast that arrives then is kept in heldToasts:
     * no banner, no sound, no entry in the list and no LED, so there is
     * nothing to tap that would launch an application and take the user out
     * of First Use - the update service's "System update available" opens
     * Settings, a message opens Messaging. Nothing is lost: once First Use is
     * over, whatever notificationmgr still has comes in (see releaseHeld()).
     */
    property bool held: false
    property var heldToasts: []

    onHeldChanged: if (!held) releaseHeld()

    /*
     * The toasts held during First Use, as they would have come in, less the
     * banner of each: a row of banners, each with its sound, for messages that
     * may be minutes old is no way to finish setting up a phone. A sticky toast
     * goes into the list, where it waits as any other does. One that is not
     * sticky ("light", or no type at all) is nothing but its banner, so it
     * still gets that one.
     */
    function releaseHeld() {
        var toasts = heldToasts;
        heldToasts = [];
        for (var i = 0; i < toasts.length; ++i)
            addToast(toasts[i], !isSticky(toasts[i]));
    }

    /*
     * A dashboard whose page swipes its own layers: Enyo 1's (enyo.Dashboard,
     * as Email's), which says how many it has in LuneOS_dashLayers. With more
     * than one, the drag is the page's, so that only the top layer goes and
     * the rest stays, as on legacy webOS; the shell's swipe would take it and
     * slide the whole window. With one left, the shell slides the dashboard as
     * a whole, as it does any other.
     */
    function swipesOwnLayers(window) {
        return !!window && !!window.windowProperties &&
               Number(window.windowProperties["LuneOS_dashLayers"]) > 1;
    }

    // A notification is a toast that is not "light": it goes in the list too.
    function isSticky(notifObject) {
        return !!notifObject.type && notifObject.type !== "light";
    }

    /*
     * Toasts are listed in groups, as legacy webOS listed dashboards: one
     * entry per group, showing the newest toast, with the count badged on its
     * icon once there is more than one.
     *
     * On legacy the app chose the groups, by putting notifications in one
     * dashboard window or another: Email had one per account, Messaging one
     * for all messages. Here a group is an app's toasts with the same groupId,
     * which the app can pass to createToast; an app that passes none gets one
     * group, as Messaging had.
     *
     * toastGroups maps a group's key to its toasts, oldest first, as the
     * toast model's rows: those are live, so a repeat that notificationmgr's
     * client writes over a row in place (see removeToastEntry) is followed.
     * The entries in this model are what is listed; a key with no entry is
     * left over and taken as empty. An entry's belowNotifObject is the toast
     * under its newest, which a swipe of the top layer uncovers (see
     * NotificationItem), or null.
     */
    property var toastGroups: ({})

    function groupKeyOf(notifObject) {
        return (notifObject.sourceId || notifObject.ownerId || "") + "\n" + (notifObject.groupId || "");
    }

    function indexOfGroup(groupKey) {
        for (var i = 0; i < mergedModel.count; ++i) {
            if (mergedModel.get(i).notifType === "notification" &&
                mergedModel.get(i).groupKey === groupKey)
                return i;
        }
        return -1;
    }

    function addToast(notifObject, withBanner) {
        if (withBanner)
            addBannerNotification(notifObject);

        if (!isSticky(notifObject))
            return;

        var key = groupKeyOf(notifObject);
        var row = indexOfGroup(key);
        if (row < 0) {
            toastGroups[key] = [notifObject];
            mergedModel.append({"notifType": "notification",
                                "appKey": notifObject.sourceId || notifObject.ownerId || "",
                                "groupKey": key,
                                "groupCount": 1,
                                "window": null,
                                "notifObject": notifObject,
                                "belowNotifObject": null,
                                "notifHeight": dashboardCardFixedHeight});
        } else {
            toastGroups[key].push(notifObject);
            mergedModel.setProperty(row, "notifObject", notifObject);
            mergedModel.setProperty(row, "belowNotifObject", toastGroups[key][toastGroups[key].length - 2]);
            mergedModel.setProperty(row, "groupCount", toastGroups[key].length);
        }
    }

    /*
     * Drives the notification LED off the same toast model. It lives here
     * rather than in CardShell so that there is exactly one of it: the phone
     * and tablet notification areas each build their own merged model, but only
     * one of the two is ever loaded, and NotificationService - whose
     * subscription to notificationmgr this shares - is created per model.
     */
    property NotificationLed notificationLed: NotificationLed {
        notificationModel: notificationService.toastModel
        held: mergedModel.held
    }
    property Connections toastsListModelCnx: Connections {
        target: notificationService.toastModel
        // the signal itemAdded is declared in C++, without a qmltype declaration,
        // so QML isn't able to guess the name of the signal argument.
        // Rows come and go several at a time too (the toasts already waiting
        // when the shell starts, several withdrawn at once): every one of
        // first to last is taken, not only the last. A row left out of a
        // removal stayed in its group after it had gone, and its entry
        // showed nothing.
        function onRowsInserted(index, first, last) {
            for (var row = first; row <= last; ++row)
                toastInserted(notificationService.toastModel.get(row));
        }
        function onRowsAboutToBeRemoved(index, first, last) {
            for (var row = first; row <= last; ++row)
                toastRemoved(notificationService.toastModel.get(row));
        }
    }
    function toastInserted(notifObject) {
        if (mergedModel.held) {
            // A copy: the row is the model's, and the model may go on
            // changing it while the toast waits.
            heldToasts = heldToasts.concat([JSON.parse(JSON.stringify(notifObject))]);
            return;
        }

        // Banner in all cases; also in the list unless it is "light"
        addToast(notifObject, true);
    }
    function toastRemoved(notifObject) {
        let toastId = getToastIdFromNotif(notifObject);

        // The banner popup is a separate model, so removing the sticky
        // entry below is not enough: a banner still on screen when its
        // toast is withdrawn would sit there until its own timer expired.
        removeBannerNotification(notifObject);
        removeToastEntry(toastId);
        // Withdrawn before First Use was over: it no longer comes in then.
        heldToasts = heldToasts.filter(function(entry) {
            return getToastIdFromNotif(entry) !== toastId;
        });
    }
    // Takes one toast out of its group, if it is still listed: the group's
    // entry then shows the newest of the rest, or goes once none are left.
    // Both the user closing it and notificationmgr withdrawing it end up here,
    // in either order, so finding nothing is normal.
    function removeToastEntry(toastId) {
        for( var i=0; i<mergedModel.count; ++i ) {
            var entry = mergedModel.get(i);
            if (entry.notifType !== "notification")
                continue;
            var toasts = toastGroups[entry.groupKey] || [];
            for (var j = 0; j < toasts.length; ++j) {
                if (getToastIdFromNotif(toasts[j]) !== toastId)
                    continue;
                toasts.splice(j, 1);
                if (toasts.length === 0) {
                    delete toastGroups[entry.groupKey];
                    mergedModel.remove(i);
                } else {
                    mergedModel.setProperty(i, "notifObject", toasts[toasts.length - 1]);
                    mergedModel.setProperty(i, "belowNotifObject", toasts.length > 1 ? toasts[toasts.length - 2] : null);
                    mergedModel.setProperty(i, "groupCount", toasts.length);
                }
                return;
            }
        }
    }

    property WindowModel listDashboardsModel : WindowModel {
        surfaceSource: compositorInstance.surfaceModel
        acceptFunction: "filter"

        function filter(surfaceItem) {
            // TBC: is this check correct ?
            return (surfaceItem.type === "_WEBOS_WINDOW_TYPE_FLOATING" /* && windowProperties["LuneOS_window"] === "dashboard" */);
        }

        onRowsInserted: (index, first, last) => {
            var window = listDashboardsModel.get(last);
            window.visible = false;

            // Handle dashboards with custom height
            var dashHeight = 0;
            if( window.windowProperties && window.windowProperties.hasOwnProperty("LuneOS_dashheight") )
            {
                //If the provide it in GridUnits we need to make sure we deal with it properly.
                if( window.windowProperties.hasOwnProperty("LuneOS_metrics") && window.windowProperties["LuneOS_metrics"]==="units")
                {
                    dashHeight = Units.gu(window.windowProperties["LuneOS_dashheight"]);
                }
                //Provided in normal pixels, convert to device pixels
                else
                {
                    dashHeight = Units.length(window.windowProperties["LuneOS_dashheight"]);
                }
            }
            if( dashHeight<=0 ) dashHeight = dashboardCardFixedHeight;

            if( notificationArea.state === "hidden" || notificationArea.state == "open" ) {
                notificationArea.state = "minimized";
            }
            mergedModel.append({"notifType": "dashboard",
                                // the roles a toast's entry has: a view follows only
                                // the roles the model's first row came with
                                "groupKey": "",
                                "groupCount": 1,
                                "appKey": window.appId || "",
                                "window": window,
                                "notifObject": null,
                                "belowNotifObject": null,
                                "notifHeight": dashHeight});
        }
        onRowsAboutToBeRemoved: (index, first, last) => {
            var window = listDashboardsModel.get(last);
            for( var i=0; i<mergedModel.count; ++i ) {
                if( mergedModel.get(i).window && mergedModel.get(i).window === window ) {
                    mergedModel.remove(i);
                    break;
                }
            }
        }
    }

    property Component notificationItemDelegate: Component {
        NotificationItem {
            id: notificationItem

            property var notifObject: loaderNotifObject;
            property var expiryDiff: notifObject ? notifObject.schedule.expire*1000 - Date.now() : 0;

            signal clicked()
            signal closed()

            Timer {
                id: expiryTimer
                interval: Math.max(5000, Math.min(expiryDiff, 2000000000 /*never exceed max int32 value*/))
                repeat: false
                running: true
                onTriggered: notificationItem.closed()
            }

            title: notifObject.title || notifObject.message
            body: notifObject.message
            // The group's size; the areas' loaders pass it, a bare loader
            // (as in some tests) shows a single toast.
            count: typeof loaderGroupCount !== "undefined" ? loaderGroupCount : 1
            pressed: tapArea.pressed
            // A group's top layer slides on its own (see SwipeableNotification).
            layerOffset: typeof loaderLayerOffset !== "undefined" ? loaderLayerOffset : 0
            property var belowObject: typeof loaderBelowNotifObject !== "undefined" ? loaderBelowNotifObject : null
            belowTitle: belowObject ? (belowObject.title || belowObject.message || "") : ""
            belowBody: belowObject ? (belowObject.message || "") : ""

            /*
             * The entry is a group's, and shows its newest toast: when one
             * joins the group or the newest goes, the model hands the loader
             * another toast, and the item takes that one up as it took up the
             * first.
             */
            property var liveNotifObject: loaderNotifObject
            property bool _completed: false
            onLiveNotifObjectChanged: {
                if (_completed && liveNotifObject)
                    takeUp(liveNotifObject);
            }

            function takeUp(live) {
                iconPathServices.setIconUrlOrDefault(live.iconPath, live.sourceId, function(resolvedUrl) { notificationItem.iconUrl = resolvedUrl; });
                // work on a copy, to avoid warning when model is destroyed
                notifObject = JSON.parse(JSON.stringify(live));
                expiryTimer.restart();
            }

            Component.onCompleted: {
                takeUp(loaderNotifObject);
                _completed = true;
            }

            onClosed: {
                // The id of the toast as it is now. A toast that repeats the
                // last one (same source, message and type) overwrites that row
                // in place with its own timestamp, and the copy taken above
                // still has the old one: closing by it closed nothing, and the
                // entry could not be swiped away. The copy is only for once
                // the row has gone.
                var live = loaderNotifObject;
                var toastId = getToastIdFromNotif(live && live.timestamp !== undefined ? live : notifObject);
                notificationLunaService.call(
                            "luna://com.webos.notification/closeToast",
                            JSON.stringify({"toastId": toastId}), undefined, onCloseNotifError);

                // By id, not by row: this item is built from a component that
                // lives here, outside the list's delegate, so it has no model
                // index. remove(undefined) removed row 0 as well.
                removeToastEntry(toastId);
            }

            MouseArea {
                id: tapArea
                anchors.fill: parent
                onClicked: {
                    // Never out of First Use: the list is hidden then, and
                    // this is the one place a notification launches an app.
                    if (mergedModel.held)
                        return;

                    // notificationmgr wraps the toast's onclick as
                    // launchParams = {id, params}; hand the app the inner
                    // params, not the whole envelope, so it sees the same
                    // parameters the toast's creator provided
                    // A tap only opens the app. On legacy webOS the shell
                    // never took a dashboard away for a tap - it went when
                    // slid away or when its app closed it - and a group's
                    // tap took its newest toast out from under the user.
                    var lp = notificationItem.notifObject.action.launchParams;
                    launcherInstance.launchApplication(lp.id, lp.params || lp);
                }
            }

            function onCloseNotifError(message) {
                console.warn("Failed to close toast: " + message);
            }

        }
    }
    property Component dashboardDelegate: Component {
        Item {
            id: dashboardItem

            property Item dashboardWindow: loaderWindow;
            property QtObject compositorInstance: loaderCompositorInstance;

            signal clicked()
            signal closed()

            onWidthChanged: if(dashboardWindow) dashboardWindow.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));

            // Behind the window, which Component.onCompleted parents here and
            // so stacks on top. Shows through a transparent dashboard window.
            NotificationBar {
                anchors.fill: parent
                visible: !Settings.tabletUi
                // A tall dashboard (dashHeight) keeps a standard entry's corners.
                cornerHeight: Units.gu(5.6)
            }

            Component.onCompleted: {
                if( dashboardWindow ) {
                    dashboardWindow.parent = dashboardItem;

                    /* This resizes only the quick item which contains the child surface but
                                             * doesn't really resize the client window */
                    dashboardWindow.anchors.fill = dashboardItem;
                    dashboardWindow.visible = true;

                    /* Resize the real client window to have the right size */
                    dashboardWindow.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));
                }
            }
            Component.onDestruction: {
                if( dashboardWindow ) dashboardWindow.visible = false;
            }

            onClosed: {
                dashboardWindow.visible = false;
                compositorInstance.closeWindow(dashboardWindow); // this will take care of removing the card from mergedModel
                dashboardWindow = null;
            }
        }
    }

    // have an object that surveys the count of notifications and notify the display if something interesting happens
    property QtObject _mergedModelObserver: QtObject {
        property int count: mergedModel.count
        onCountChanged: {
            if (count === 0 && __previousCount !== 0) {
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "banner-deactivated"}), undefined, onDisplayControlError)
            }
            else if (count !== 0 && __previousCount === 0){
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "banner-activated"}), undefined, onDisplayControlError)
            }

            __previousCount = count;
        }
        function onDisplayControlError(message) {
            console.log("Failed to call display service: " + message);
        }
        property int __previousCount: 0
    }
    property LunaService notificationLunaService: LunaService {
        name: "com.webos.surfacemanager.cardshell"
    }
    property LunaService displayService: LunaService {
        name: "com.webos.surfacemanager.cardshell"
    }
}
