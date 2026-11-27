/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.5
import LunaNext.Common 0.1

import "../Utils"
import "../Notifications"

/*
 * The notifications and dashboards on the lock screen, as LunaSysMgr's
 * LockWindow drew them (its DashboardAlerts) under the clock while the screen
 * was locked, unless Settings' "Show alerts when locked" was off.
 *
 * Two layouts, as the notification rows have (NotificationLayout.tabletStyle):
 *
 *  - webOS 2.2.4 on a phone: the rows across the screen, stacked up from just
 *    over the lock button, the newest at the bottom. At most four; the third
 *    from the bottom is drawn at half opacity and the fourth at 0.15
 *    (DashboardAlerts::paint, 0x0015b6fc on the Pre3's LunaSysMgr), so the
 *    stack fades out upwards.
 *  - webOS 3.0.5 on the TouchPad: a 320 wide popup panel in the middle of the
 *    screen, the newest on top, rows parted by a divider. At most six, with
 *    the scroll fade over the bottom one once six are shown (LunaCE's
 *    DashboardAlerts: kMaxDashboardItems, kMaxWidth, popup-bg.png 9-tiled).
 *
 * A new notification's banner shows here as well, in place of the list while
 * it plays, as LockWindow swapped its BannerAlerts in for the DashboardAlerts
 * (activateBannerAlert) and back once the banners were done:
 *
 *  - 2.2.4: a black strip with rounded corners where the stack ends, just
 *    over the lock button (BannerAlerts::paint, 0x0015bab8).
 *  - 3.0.5: the banner in a 320 wide popup panel in the middle of the screen,
 *    10 px of padding inside the panel's shadow (LunaCE's BannerAlerts).
 *
 * While this shows, the banners are this one's only: the notification areas,
 * hidden behind the lock screen, leave them alone, or each banner's sound
 * would play twice. A banner here opens nothing when tapped.
 *
 * It is the merged model's list, with its rows: a dashboard window is taken
 * from the notification area while this shows (NotificationsMergedModel's
 * onLockScreen) and given back after. Nothing on it can be swiped away, and
 * a tap reaches only a dashboard that asked to be clickable while locked;
 * anything else needs the device unlocked first.
 */
Item {
    id: lockScreenDashboards
    objectName: "lockScreenDashboards"

    property var mergedModel: null
    property QtObject compositorInstance: null

    // Whether it shows: the lock screen decides (locked, at the padlock,
    // allowed by the preference, no alert over it).
    property bool active: false

    property bool tabletStyle: NotificationLayout.tabletStyle

    // From the top of this item, the height the phone's stack may grow to:
    // it stops short of the clock.
    property real availableHeight: height

    readonly property int maxRows: tabletStyle ? 6 : 4
    readonly property real spacing: tabletStyle ? dividerHeight : Units.gu(1) / 2
    readonly property real dividerHeight: Units.gu(0.2)
    readonly property real rowWidth: tabletStyle ? Units.length(320) : width - Units.gu(1)

    // The tablet panel's border, from LunaCE: 10 of shadow around popup-bg's
    // 9 px corners; the rows are inset by the shadow only.
    readonly property int panelShadow: 10
    readonly property int panelBorder: 19

    visible: active && (shownRows > 0 || bannerShowing)

    // A banner is playing: the list waits for it.
    readonly property bool bannerShowing: banner.popupModel.count > 0
    readonly property real bannerHeight: Units.gu(3)
    // LunaCE's kPadding, between the banner and the panel's shadow
    readonly property int bannerPadding: 10

    Connections {
        target: lockScreenDashboards.mergedModel

        function onAddBannerNotification(notifObject) {
            if (lockScreenDashboards.active)
                banner.popupModel.append({"object": notifObject});
        }

        function onRemoveBannerNotification(notifObject) {
            var model = lockScreenDashboards.mergedModel;
            var toastId = model.getToastIdFromNotif(notifObject);
            for (var i = banner.popupModel.count - 1; i >= 0; i--) {
                var entry = banner.popupModel.get(i).object;
                if (entry && model.getToastIdFromNotif(entry) === toastId)
                    banner.popupModel.remove(i);
            }
        }
    }

    // Unlocked, or on to the passcode, mid-banner: it is not played on
    // elsewhere. Its toast, if it stays, is listed.
    onActiveChanged: if (!active) banner.popupModel.clear()

    readonly property int count: active && mergedModel ? mergedModel.count : 0

    // Row k counted from the newest (k = 0) is entry count - 1 - k.
    function heightFromNewest(k) {
        var entry = mergedModel.get(count - 1 - k);
        return entry ? entry.notifHeight : 0;
    }

    // How many rows show: up to maxRows, and on a phone no more than fit
    // under the clock.
    readonly property int shownRows: {
        var n = Math.min(count, maxRows);
        if (tabletStyle)
            return n;
        var used = 0;
        for (var k = 0; k < n; k++) {
            used += (k > 0 ? spacing : 0) + heightFromNewest(k);
            if (used > availableHeight)
                return k;
        }
        return n;
    }

    // From the newest end: the height of rows 0 .. k - 1 and the gaps after them.
    function offsetFromNewest(k) {
        var offset = 0;
        for (var i = 0; i < k; i++)
            offset += heightFromNewest(i) + spacing;
        return offset;
    }

    readonly property real listHeight: shownRows > 0 ? offsetFromNewest(shownRows) - spacing : 0

    // 2.2.4's fading of the stack upwards.
    function rowOpacity(k) {
        if (tabletStyle)
            return 1;
        return k === 2 ? 0.5 : k === 3 ? 0.15 : 1;
    }

    BorderImage {
        id: panelBackground
        objectName: "lockScreenDashboardsPanel"
        source: "../images/popup-bg.png"
        visible: lockScreenDashboards.tabletStyle && !lockScreenDashboards.bannerShowing
        x: rowsArea.x - lockScreenDashboards.panelShadow
        y: rowsArea.y - lockScreenDashboards.panelShadow
        width: rowsArea.width + 2 * lockScreenDashboards.panelShadow
        height: rowsArea.height + 2 * lockScreenDashboards.panelShadow
        border {
            left: lockScreenDashboards.panelBorder; top: lockScreenDashboards.panelBorder
            right: lockScreenDashboards.panelBorder; bottom: lockScreenDashboards.panelBorder
        }
    }

    Item {
        id: rowsArea
        objectName: "lockScreenDashboardsRows"

        width: lockScreenDashboards.rowWidth
        height: lockScreenDashboards.listHeight
        anchors.horizontalCenter: parent.horizontalCenter
        // A phone's stack rests on the bottom, over the lock button; the
        // tablet's panel is in the middle of the screen.
        y: lockScreenDashboards.tabletStyle ? (parent.height - height) / 2 : parent.height - height
        clip: true
        visible: !lockScreenDashboards.bannerShowing

        Repeater {
            id: rowsRepeater
            // Made only while it shows: each row is the entry's second view,
            // and the dashboards go back to the first when this goes.
            model: lockScreenDashboards.active ? lockScreenDashboards.mergedModel : null

            delegate: Item {
                id: row
                objectName: "lockScreenRow"

                readonly property int fromNewest: lockScreenDashboards.count - 1 - index
                readonly property bool shown: fromNewest < lockScreenDashboards.shownRows
                readonly property Item rowWindow: typeof window !== 'undefined' ? window : null
                readonly property bool clickable: notifType === "dashboard" &&
                                                  !!lockScreenDashboards.mergedModel &&
                                                  lockScreenDashboards.mergedModel.clickableWhenLocked(rowWindow)

                visible: shown
                width: rowsArea.width
                height: notifHeight
                opacity: lockScreenDashboards.rowOpacity(fromNewest)
                // the newest at the bottom on a phone, at the top on a tablet
                y: lockScreenDashboards.tabletStyle
                   ? lockScreenDashboards.offsetFromNewest(fromNewest)
                   : rowsArea.height - lockScreenDashboards.offsetFromNewest(fromNewest) - height

                Loader {
                    id: rowLoader
                    anchors.fill: parent
                    sourceComponent: notifType === "notification" ?
                                         lockScreenDashboards.mergedModel.notificationItemDelegate :
                                         lockScreenDashboards.mergedModel.dashboardDelegate

                    // what the delegates read, as the notification areas pass it
                    property var loaderNotifObject: typeof notifObject !== 'undefined' ? notifObject : undefined
                    property Item loaderWindow: row.rowWindow
                    property int loaderGroupCount: typeof groupCount !== 'undefined' && groupCount ? groupCount : 1
                    property var loaderBelowNotifObject: typeof belowNotifObject !== 'undefined' ? belowNotifObject : null
                    property real loaderLayerOffset: 0
                    property QtObject loaderCompositorInstance: lockScreenDashboards.compositorInstance
                    property bool loaderOnLockScreen: true

                    signal closed()
                    signal closedAll()
                }

                // Taps stop here, unless the dashboard takes them while locked:
                // a notification's tap would launch its application from
                // behind the lock screen.
                MouseArea {
                    anchors.fill: parent
                    enabled: !row.clickable
                    visible: enabled
                }

                Image {
                    objectName: "lockScreenRowDivider"
                    width: parent.width
                    height: lockScreenDashboards.dividerHeight
                    source: "../images/menu-divider.png"
                    // in the gap under each row but the lowest, the oldest shown
                    anchors.top: parent.bottom
                    visible: lockScreenDashboards.tabletStyle &&
                             row.fromNewest < lockScreenDashboards.shownRows - 1
                }
            }
        }

        // LunaCE drew it over the last row whenever there were six.
        Image {
            objectName: "lockScreenDashboardsFade"
            source: "../images/dashboard-scroll-fade.png"
            width: parent.width
            anchors.bottom: parent.bottom
            visible: lockScreenDashboards.tabletStyle &&
                     lockScreenDashboards.shownRows === lockScreenDashboards.maxRows
        }
    }

    // The tablet's banner panel, and the phone's strip.
    BorderImage {
        objectName: "lockScreenBannerPanel"
        source: "../images/popup-bg.png"
        visible: banner.visible && lockScreenDashboards.tabletStyle
        x: banner.x - lockScreenDashboards.panelShadow - lockScreenDashboards.bannerPadding
        y: banner.y - lockScreenDashboards.panelShadow - lockScreenDashboards.bannerPadding
        width: banner.width + 2 * (lockScreenDashboards.panelShadow + lockScreenDashboards.bannerPadding)
        height: banner.height + 2 * (lockScreenDashboards.panelShadow + lockScreenDashboards.bannerPadding)
        border {
            left: lockScreenDashboards.panelBorder; top: lockScreenDashboards.panelBorder
            right: lockScreenDashboards.panelBorder; bottom: lockScreenDashboards.panelBorder
        }
    }

    Rectangle {
        objectName: "lockScreenBannerStrip"
        visible: banner.visible && !lockScreenDashboards.tabletStyle
        anchors.fill: banner
        color: "black"
        radius: Units.gu(1)
    }

    BannerPopupArea {
        id: banner
        objectName: "lockScreenBanner"

        // the phone's ticker, sliding up, in either layout: the tablet's
        // slides in from the side of the status bar
        tablet: false
        color: "transparent"
        // nothing is opened from behind the lock
        mergedModel: null

        visible: lockScreenDashboards.bannerShowing
        width: lockScreenDashboards.rowWidth
        height: lockScreenDashboards.bannerHeight
        anchors.horizontalCenter: parent.horizontalCenter
        // where the phone's stack ends, over the lock button; the middle of
        // the screen on a tablet
        y: lockScreenDashboards.tabletStyle ? (parent.height - height) / 2 : parent.height - height
    }
}
