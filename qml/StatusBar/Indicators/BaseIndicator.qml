/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013-2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2014 Herman van Hazendonk <github.com@herrie.org>
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

Item {
    id: indicatorRoot

    property string imageSource: ""
    property bool enabled: true
    property string textValue: ""
    property string textColor: "white"

    property bool imageVisible: true
    property bool textVisible: false


    width: getIndicatorWidth(imageVisible, textVisible, indicatorImage.width, indicatorText.contentWidth)

    function getIndicatorWidth(imageVisible, textVisible, indicatorImageWidth, indicatorTextWidth)
    {
        if (imageVisible){
            if (textVisible){
                return Math.max(indicatorImageWidth, indicatorTextWidth)
            }
            else {
                return indicatorImageWidth;
            }
        }
        else if (textVisible) {
            return indicatorTextWidth;
        }
        return 0;
    }

    clip: true
    visible: enabled

    Image {
        id: indicatorImage
        fillMode: textVisible ? Image.Stretch : Image.PreserveAspectFit;
        width: textVisible ? indicatorRoot.width : undefined
        mipmap: true
        source: imageSource
        anchors.left: indicatorRoot.left
        anchors.bottom: indicatorRoot.bottom
        height: indicatorRoot.height
        transform: [
            Rotation { angle: textVisible?270:0; origin.x: indicatorImage.width/2; origin.y: indicatorImage.height/2 },
            Scale { xScale: 1; yScale: textVisible?0.5:1; origin.x: indicatorImage.width/2; origin.y: indicatorImage.height }
        ]
        visible: imageVisible
    }

    Text {
        id: indicatorText
        color: textColor
        font.family: Settings.fontStatusBar
        font.bold: !imageVisible
        text: textValue
        font.pixelSize: imageVisible?((parent.height/2)*0.95):(parent.height*0.95);
        anchors.fill: indicatorRoot
        transform: [
            Rotation { origin.x: indicatorImage.width/2; origin.y: indicatorImage.height/2 }
        ]
        visible: textVisible

    }


    states: [
        State {
            name: "visible"
            when: enabled
        },
        State {
            name: "hidden"
            when: !enabled
        }
    ]

    transitions: [
        Transition {
            from: "visible"
            to: "hidden"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: indicatorImage; properties: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                    NumberAnimation { target: indicatorText; properties: "opacity"; from: 1.0; to: 0.0; duration: 200 }
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
                    NumberAnimation { target: indicatorText; properties: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                    NumberAnimation { target: indicatorRoot; properties: "width"; from: 0; to: indicatorImage.width; duration: 400 }
                }
            }
        }
    ]
}
