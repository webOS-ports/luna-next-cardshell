/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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

import "../Utils"

SlidingItemArea {
    slidingTargetItem: notificationGradientRectangle
    filterChildren: true

    Rectangle {
        id: notificationGradientRectangle

        property color buttonColor: "#2f2f2f";
        radius: 15

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: 0
        width: parent.width

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(notificationGradientRectangle.buttonColor, 1.5) }
            GradientStop { position: 1.0; color: notificationGradientRectangle.buttonColor }
        }

        Row {
            id: fullNotificationRow

            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: model.icon
                width: notificationGradientRectangle.height * 0.8;
                height: notificationGradientRectangle.height * 0.8;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                text: model.htmlContent
            }
        }
    }
}
