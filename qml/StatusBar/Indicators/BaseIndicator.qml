/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013-2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013-2014 Herman van Hazendonk <github.com@herrie.org>
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

Item {
    id: indicatorRoot

    property string imageSource: ""
    property bool enabled: true
    property int pixelSizeDivider: 1
    property string textValue: ""
    property string textColor: "white"
    property int leftMargin: 0
    property int textRotation: 0

    property bool imageVisible: true
    property bool textVisible: false


    width: getIndicatorWidth(imageVisible, textVisible, indicatorImage.width, indicatorText.contentWidth)

    function getIndicatorWidth(imageVisible, textVisible, indicatorImageWidth, indicatorTextWidth)
    {
    //Check if we show the image
        if (imageVisible)
        {
            //Check if we also show the text
            if (textVisible)
            {
                //return the max width for image or text
                return Math.max(indicatorImageWidth, indicatorTextWidth)
            }
            else
            {
                //When we only have image, we'll return it's width
                return indicatorImageWidth;
            }
        }
        else if (textVisible)
        {
            //We only have text so we return it's width
            return indicatorTextWidth;
        }
		return 0;
    }

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
        visible: imageVisible
    }

    Text {
        id: indicatorText
        color: textColor
        font.family: Settings.fontStatusBar
        font.pixelSize: (parent.height / pixelSizeDivider) * 0.95
        font.bold: {if(pixelSizeDivider === 1) true; else false}
        text: textValue
        rotation: textRotation
        anchors.left: indicatorRoot.left
        anchors.top: indicatorRoot.top
        anchors.bottom: indicatorRoot.bottom
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

    Component.onCompleted: {
        // initialize the visible property directly without doing any transition animation
        visible = enabled ? true : false;
    }

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
