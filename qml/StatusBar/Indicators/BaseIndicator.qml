/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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

Item {
    id: indicatorRoot

    property string imageSource: ""
    property bool enabled: true

    width: indicatorImage.width
    clip: true
    visible: true

    Image {
        id: indicatorImage
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: imageSource
        anchors.left: indicatorRoot.left
        anchors.top: indicatorRoot.top
        anchors.bottom: indicatorRoot.bottom
    }

    states: [
        State {
            name: "visible"
        },
        State { name: "hidden" }
    ]

    state: enabled ? "visible" : "hidden"

    Component.onCompleted: {
        if (state === "visible")
            visible = true;
        else if (state === "hidden")
            visible = false;
    }

    transitions: [
        Transition {
            from: "visible"
            to: "hidden"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: indicatorImage; properties: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                    NumberAnimation { target: indicatorRoot; properties: "width"; from: indicatorImage.width; to: 0; duration: 400 }
                }
                PropertyAction { target: indicatorRoot; properties: "visible"; value: false }
            }
        },
        Transition {
            from: "hidden"
            to: "visible"
            SequentialAnimation {
                PropertyAction { target: indicatorRoot; properties: "visible"; value: true }
                ParallelAnimation {
                    NumberAnimation { target: indicatorImage; properties: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                    NumberAnimation { target: indicatorRoot; properties: "width"; from: 0; to: indicatorImage.width; duration: 400 }
                }
            }
        }
    ]
}
