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

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import LuneOS.Service 1.0

import "../Utils"

// The notification area can take three states:
//  - hidden: nothing is shown
//  - minimized: only notification icons are shown
//  - open: all notifications with their content are shown

Rectangle {
    id: notificationArea

    property QtObject compositorInstance
    property Item windowManagerInstance

    /*
     * Notifications are held while First Use runs: none of them is shown,
     * sounds or can be tapped, as tapping one launches its application and
     * takes the user out of First Use. They come in once it is over; see
     * NotificationsMergedModel.held.
     */
    readonly property bool held: !!windowManagerInstance && windowManagerInstance.state === "firstuse"

    visible: !held
    enabled: !held

    property int maxDashboardWindowHeight: parent.height/2
    readonly property int dashboardCardFixedHeight: Units.gu(5.6) // this value comes from the CSS of the dashboard cards
    readonly property int bannerNotificationFixedHeight: Units.gu(2.4) // this value comes from the CSS of the banner

    height: 0
    color: "black"
    /* hidden by default as long as we don't any notifications */
    state: "hidden"

    IconPathServices {
        id: iconPathServices
    }

    // What is listed: CardsArea's, which outlives this area (see
    // NotificationsMergedModel), its held set there from First Use too.
    property NotificationsMergedModel mergedModel

    Connections {
        target: notificationArea.mergedModel

        function onAddBannerNotification(notifObject) {
           bannerItemsPopups.popupModel.append({"object": notifObject});
        }

        function onRemoveBannerNotification(notifObject) {
           let toastId = notificationArea.mergedModel.getToastIdFromNotif(notifObject);
           for (var i = bannerItemsPopups.popupModel.count - 1; i >= 0; i--) {
               let entry = bannerItemsPopups.popupModel.get(i).object;
               if (entry && notificationArea.mergedModel.getToastIdFromNotif(entry) === toastId)
                   bannerItemsPopups.popupModel.remove(i);
           }
        }

        function onDashboardAdded() {
            if( notificationArea.state === "hidden" || notificationArea.state == "open" ) {
                notificationArea.state = "minimized";
            }
        }
    }

    // Minimized view
    Row {
        id: minimizedListView

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Units.gu(1)/2
        }

        height: notificationArea.mergedModel.count > 0 ? Units.gu(3) : 0;

        layoutDirection: Qt.RightToLeft

        Repeater {
            model: notificationArea.mergedModel
            delegate: Image {
                    id: notifIconImage
                    // One icon per application and icon (see firstIndexOfIcon).
                    // Reading count re-evaluates this as entries come and go.
                    visible: notificationArea.mergedModel.count > 0 &&
                             (model.appKey === "" || notificationArea.mergedModel.firstIndexOfIcon(model.iconKey) === index)
                    height: minimizedListView.height
                    width: height
                    fillMode: Image.PreserveAspectFit

                    function setSourceIcon(resolvedUrl) {
                        notifIconImage.source = resolvedUrl;
                    }

                    // set the source asynchronously
                    Component.onCompleted: {
                        // if it's a dashboard, iconUrl is equal to: getIconUrl(myIconUrl, window.appId),
                        // if it's a notification, it's simply getIconUrlOrDefault(iconUrl, ownerId, "mergedModel")

                        // so, if it's a window, we need to call setIconUrlFromWindow first
                        if(model.window) {
                            iconPathServices.setIconUrlFromWindow(model.window, function(resolvedUrl) {
                                iconPathServices.setIconUrlOrDefault(resolvedUrl, window.appId, setSourceIcon);
                            });
                        } else if(notifObject) {
                            iconPathServices.setIconUrlOrDefault(notifObject.iconPath, notifObject.ownerId, setSourceIcon);
                        }
                    }

            }
        }
    }

    // A banner still on its way when the hold starts goes: it would only
    // come back, half played, once First Use is over.
    onHeldChanged: if (held) bannerItemsPopups.popupModel.clear()

    // Opening registers a tap action (below). Whatever takes the area out of
    // "open" drops it again: not only a tap, but also the last notification
    // going away ("hidden") or a new one coming in ("banner") - left behind,
    // the stale action ate the next tap on the gesture area.
    onStateChanged: {
        if (notificationArea.state !== "open" && windowManagerInstance)
            windowManagerInstance.removeTapAction("minimizeNotificationArea");
    }

    function minimizeNotificationArea() {
        if( notificationArea.state === "open" )
            notificationArea.state = "minimized";
    }

    MouseArea {
        anchors.fill: minimizedListView
        enabled: minimizedListView.visible
        onClicked: {
            bannerItemsPopups.popupModel.clear();
            notificationArea.state = "open";
            windowManagerInstance.addTapAction("minimizeNotificationArea", minimizeNotificationArea, null)
        }
    }

    // Tablet style down here: the rows have no bar of their own, so they sit
    // on the status bar drop-down's panel and are parted by its dividers, as
    // NotificationAreaTablet draws them, rather than straight on the black.
    // Under the list by coming before it, not by a negative z, which would
    // put it under this area's own black too.
    BorderImage {
        id: openListViewBg
        objectName: "openListViewBg"
        source: "../images/menu-dropdown-bg.png"
        x: openListView.x - 11
        y: openListView.y
        width: openListView.width + 22
        height: openListView.height + 14
        smooth: false
        border { left: 30; top: 10; right: 30; bottom: 30 }
        visible: openListView.visible && NotificationLayout.tabletStyle
    }

    ListView {
        id: openListView
        objectName: "openListView"

        visible: false
        interactive: height === maxDashboardWindowHeight
        clip: interactive
        orientation: ListView.Vertical
        // LunaSysMgr scrolled the phone's dashboards by whole entries.
        snapMode: ListView.SnapToItem
        cacheBuffer: maxDashboardWindowHeight
        height: Math.min(maxDashboardWindowHeight, contentHeight);
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Units.gu(1)/2
        }

        spacing: NotificationLayout.tabletStyle ? 2 : Units.gu(1) / 2
        model: notificationArea.mergedModel

        delegate:
            SwipeableNotification {
                id: slidingNotificationArea

                property var delegateNotifObject: typeof notifObject !== 'undefined' ? notifObject : undefined;
                property Item delegateWindow: typeof window !== 'undefined' ? window : null;
                property string delegateType: notifType;
                property int delegateHeight: notifHeight
                property int delegateGroupCount: typeof groupCount !== 'undefined' && groupCount ? groupCount : 1
                property var delegateBelowNotifObject: typeof belowNotifObject !== 'undefined' ? belowNotifObject : null
                layered: delegateType === "notification" && delegateGroupCount > 1
                // an Enyo dashboard with layers swipes them itself
                interactive: !notificationArea.mergedModel.swipesOwnLayers(delegateWindow)
                // the next toast of a group whose top one was swiped away
                onDelegateNotifObjectChanged: comeBack()
                property int delegateIndex: index

                notifComponent: notificationItemLoaderComponent

                height: delegateHeight
                width: notificationArea.width - Units.gu(1)

                Image {
                    objectName: "rowDivider"
                    width: parent.width
                    height: Units.gu(0.2)
                    source: "../images/menu-divider.png"
                    anchors.top: parent.bottom
                    anchors.topMargin: (openListView.spacing - height) / 2.
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: NotificationLayout.tabletStyle &&
                             slidingNotificationArea.delegateIndex < openListView.count - 1
                }

                Component {
                    id: notificationItemLoaderComponent

                    Loader {
                        id: notificationItemLoader
                        width: slidingNotificationArea.width
                        height: slidingNotificationArea.delegateHeight

                        sourceComponent: slidingNotificationArea.delegateType === "notification" ?
                                             notificationArea.mergedModel.notificationItemDelegate :
                                             notificationArea.mergedModel.dashboardDelegate

                        property var loaderNotifObject: slidingNotificationArea.delegateNotifObject
                        property Item loaderWindow: slidingNotificationArea.delegateWindow
                        property int loaderGroupCount: slidingNotificationArea.delegateGroupCount
                        property var loaderBelowNotifObject: slidingNotificationArea.delegateBelowNotifObject
                        property real loaderLayerOffset: slidingNotificationArea.layerOffset
                        property QtObject loaderCompositorInstance: compositorInstance

                        signal closed()
                        onClosed: {
                            item.closed();
                        }
                    }
                }

                onRequestDestruction: slidingNotificationArea.notifItem.closed();
        }

        Behavior on height {
            NumberAnimation { duration: 150 }
        }
    }

    // Banner popup view
    BannerPopupArea {
        id: bannerItemsPopups
        objectName: "bannerPopupArea"
        tablet: false
        visible: height>0

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        height: popupModel.count > 0 ? bannerNotificationFixedHeight : 0;
        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
    }

    states: [
        // First in the list, so it wins over the others while it holds; it
        // takes no room, so the card above reaches down to the gesture area.
        State {
            name: "held"
            when: notificationArea.held
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: 0 }
        },
        State {
            name: "hidden"
            when: (bannerItemsPopups.popupModel.count + notificationArea.mergedModel.count) === 0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: 0 }
        },
        State {
            name: "banner"
            when: bannerItemsPopups.popupModel.count>0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: bannerItemsPopups.height }
        },
        State {
            name: "minimized"
            when: bannerItemsPopups.popupModel.count===0 && !openListView.visible
            PropertyChanges { target: minimizedListView; visible: true }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: minimizedListView.height+Units.gu(1) }
        },
        State {
            name: "open"
            when: bannerItemsPopups.popupModel.count===0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: true }
            PropertyChanges { target: notificationArea; height: openListView.height+Units.gu(1) }
        }
    ]
}
