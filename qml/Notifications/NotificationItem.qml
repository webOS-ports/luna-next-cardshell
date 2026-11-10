/*
 * Copyright (C) 2015-2016 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2016 Herman van Hazendonk <github.com@herrie.org>
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
import LunaNext.Common 0.1

import "../Utils"

/*
 * One entry of the notification area, in legacy webOS's dashboard look: the
 * webOS 2.2.4 pill on phones, webOS 3.0.5's flat row in the drop-down on
 * tablets. All sizes are proportions of the entry's height, so they hold at
 * any density.
 *
 * An entry stands for a group of notifications (see NotificationsMergedModel)
 * and shows the newest; count is how many there are. With more than one:
 *  - phone: the pill splits into an icon pill and a text pill, 4/48 of the
 *    height apart, with the count badge on the icon - Mojo's "multi" layout;
 *  - tablet: the badge goes on the icon, and the newest sits on top of the
 *    others as a card with a shadowed left edge - Enyo's stacked layers.
 *
 * Swiping a group takes its top layer only, as Enyo's dashboard did (each
 * text layer a swipeable of its own, the icon and the layers under it left
 * where they are): layerOffset is how far the top layer has been dragged,
 * and the toast under it (belowTitle, belowBody) shows in what it uncovers.
 * Phone: the text pill and its text slide, under the icon pill, over a pill
 * that shows the next toast. Tablet: the card and its text slide, and the
 * next toast shows between the card's old edge and where it is now - Enyo
 * clipped the layer under to the drag (DashboardLayer.configureClipping).
 */
Item {
    id: notification

    property string title: "(no title)"
    property string body: "(no summary)"
    property url iconUrl: Qt.resolvedUrl("../images/default-app-icon.png");
    property int count: 1
    // Held down, and where: across the entry, from its left.
    property bool pressed: false
    property real pressX: 0
    // The top layer of a group, dragged this far to the right (negative: to
    // the left); the toast under it.
    property real layerOffset: 0
    property string belowTitle: ""
    property string belowBody: ""

    readonly property bool grouped: count > 1
    // The look Settings' Notifications page chose, the device's own by default
    readonly property bool tablet: NotificationLayout.tabletStyle

    /*
     * What a press lights, as on legacy webOS. A phone's is webOS 2.2.4's:
     * Mojo lit the half that was touched (.palm-dashboard-icon-container:active
     * and .palm-dashboard-text-container:active), the icon's with the pressed
     * badge, and a single notification's whole entry (.single:active). A
     * tablet's is 3.0's, where Enyo's dashboards lit nothing. A swipe takes
     * the press from the tap area, so nothing stays lit as an entry slides.
     */
    readonly property bool _pressOnIcon: pressX < iconPillWidth + pillGap / 2
    readonly property bool iconLit: pressed && !tablet && (!grouped || _pressOnIcon)
    readonly property bool textLit: pressed && !tablet && grouped && !_pressOnIcon

    // Phone: the icon pill of a split entry, and the gap after it (Mojo: a
    // 54 px icon cap, the text cap 4 px further on, on a 48 px pill).
    readonly property real iconPillWidth: height * 1.02
    readonly property real pillGap: height * 4 / 48
    // and the text, in heights from the left
    readonly property real phoneTextX: 1.34
    // Tablet: Enyo's icon container, 6 px in and 50 px wide on a 52 px row;
    // the text 74 px in, or 79 px on the top card of a stack, whose shadow
    // starts at 58 px.
    readonly property real tabletIconCellX: height * 6 / 52
    readonly property real tabletIconCellWidth: height * 50 / 52
    readonly property real tabletCardX: height * 58 / 52

    // Over the sliding layer only as the icon pill of a group. A single
    // toast's bar is the whole entry, and above its text it hid every word.
    NotificationBar {
        id: bar
        z: notification.grouped ? 2 : 0
        visible: !notification.tablet
        pressed: notification.iconLit
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: notification.grouped ? notification.iconPillWidth : parent.width
    }

    // Phone, grouped: the pill of the toast under the top one, uncovered as
    // the top one slides away.
    NotificationBar {
        id: belowBar
        visible: textBar.visible && notification.layerOffset !== 0
        anchors.fill: textBar
    }
    LayerText {
        visible: belowBar.visible
        anchors.left: textColumn.left
        anchors.right: textColumn.right
        anchors.verticalCenter: textColumn.verticalCenter
        title: notification.belowTitle
        body: notification.belowBody
    }

    // Tablet, grouped: the toast under the top card, in the strip the card
    // has moved off.
    Item {
        visible: notification.tablet && notification.grouped && notification.layerOffset > 0
        x: notification.tabletCardX
        width: Math.max(0, notification.layerOffset)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        LayerText {
            x: textColumn.x - parent.x
            width: textColumn.width
            anchors.verticalCenter: parent.verticalCenter
            title: notification.belowTitle
            body: notification.belowBody
        }
    }

    NotificationBar {
        id: textBar
        z: 1
        visible: !notification.tablet && notification.grouped
        pressed: notification.textLit
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: bar.right
        anchors.leftMargin: notification.pillGap
        transform: Translate { x: notification.layerOffset }
    }

    // Tablet, stacked: the top card's left edge, as Enyo's
    // notification-divider.png - a shadow fading in over ten pixels onto the
    // card below, then a black line and a #555 one.
    Item {
        id: cardEdge
        z: 1
        visible: notification.tablet && notification.grouped
        transform: Translate { x: notification.layerOffset }
        x: notification.tabletCardX
        width: notification.height * 12 / 52
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 10 / 12
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#54000000" }
            }
        }
        Rectangle {
            x: parent.width * 10 / 12
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "black"
        }
        Rectangle {
            x: parent.width * 10 / 12 + 1
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "#555555"
        }
    }

    // Enyo's and Mojo's 48 px icon on a 52 px row, centred in Enyo's icon
    // cell on a tablet and on the icon pill on a phone, as webOS 2.2.4 had it
    // whether the entry was split or not. Icons carry their own margin (an
    // application's icon fills 0.84 to 0.91 of its image), so what shows is
    // about 0.8 of the row, as on a Pre.
    readonly property real iconSize: height * 48 / 52
    Image {
        id: notificationIcon
        objectName: "notificationIcon"
        z: 2
        anchors.verticalCenter: parent.verticalCenter
        x: notification.tablet ?
               notification.tabletIconCellX + (notification.tabletIconCellWidth - width) / 2 :
               (notification.iconPillWidth - width) / 2
        height: notification.iconSize
        width: height
        source: iconUrl
        fillMode: Image.PreserveAspectFit
        layer.mipmap: true
    }

    NotificationBadge {
        id: badge
        z: 2
        visible: notification.grouped
        pressed: notification.iconLit
        count: notification.count
        height: notification.height * 20 / 48
        // On the icon's top right corner and a little past it: over the gap
        // on a phone, as Mojo's badge hung 3 px off the icon cap.
        x: notification.tablet ?
               notification.tabletIconCellX + notification.tabletIconCellWidth + notification.height * 3 / 52 - width :
               notification.iconPillWidth + notification.height * 3 / 48 - width
        y: notification.tablet ? notification.height * 3 / 52 : 0
    }

    LayerText {
        id: textColumn
        z: 1
        anchors.left: parent.left
        // Phone: 1.34 of the height in, split or not, where a Pre's text was.
        anchors.leftMargin: notification.tablet ?
                                (notification.grouped ? notification.tabletCardX + parent.height * 21 / 52
                                                      : parent.height * 74 / 52) :
                                parent.height * notification.phoneTextX
        anchors.right: parent.right
        anchors.rightMargin: parent.height * 0.2
        anchors.verticalCenter: parent.verticalCenter
        transform: Translate { x: notification.grouped ? notification.layerOffset : 0 }
        title: notification.title
        body: notification.body
    }

    // A layer's two lines: the title, and the body under it - 16 px under a
    // 16 px title on webOS 2.2.4, 14 px on 3.0.5.
    component LayerText: Column {
        property string title
        property string body
        spacing: 0

        Text {
            width: parent.width
            font.bold: true
            font.pixelSize: FontUtils.sizeToPixels("medium")
            color: "white"
            elide: Text.ElideRight
            text: parent.title
            textFormat: Text.PlainText
        }
        Text {
            width: parent.width
            font.pixelSize: FontUtils.sizeToPixels(notification.tablet ? "small" : "medium")
            font.bold: false
            color: "white"
            elide: Text.ElideRight
            text: parent.body
            textFormat: Text.PlainText
        }
    }
}
