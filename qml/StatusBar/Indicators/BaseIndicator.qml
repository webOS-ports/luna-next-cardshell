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

    /*
     * The widest reading this indicator will ever show, e.g. "100%". The icon
     * beside a reading is drawn from the indicator's width - rotated a quarter
     * turn, so that width becomes the icon's height, and clipped to it - which
     * means sizing to the live text redraws the icon at a different size every
     * time the reading changes width. Two batteries then look like different
     * hardware for no better reason than one reading 96% and the other 100%,
     * and a single one changes shape on its way down from 100. Empty keeps the
     * old behaviour of measuring whatever is currently shown.
     */
    property string textReferenceValue: ""

    TextMetrics {
        id: referenceMetrics
        font: indicatorText.font
        text: indicatorRoot.textReferenceValue
    }

    readonly property real __textWidth: Math.max(indicatorText.contentWidth,
                                                 textReferenceValue.length > 0
                                                     ? referenceMetrics.width : 0)


    width: getIndicatorWidth(imageVisible, textVisible, indicatorImage.width, __textWidth)

    function getIndicatorWidth(imageVisible, textVisible, indicatorImageWidth, indicatorTextWidth)
    {
        if (imageVisible){
            if (textVisible){
                /*
                 * Not Math.max(indicatorImageWidth, ...): with the text shown
                 * the image is stretched to this very width, so that asked the
                 * binding about itself. width = max(width, contentWidth) holds
                 * for every width at or above contentWidth, and which of them
                 * it settled on came down to evaluation order - two indicators
                 * running the same code landed on 41 and 65, and since the icon
                 * is drawn centred while the reading is drawn from the left,
                 * the wider one had its cell pushed out from under its digits.
                 * The reading is the only measure here that does not depend on
                 * the answer, and the icon is drawn to fit whatever it gives.
                 */
                return indicatorTextWidth;
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
        // Text-only fills the bar on its own, so it does not need the height an
        // icon-and-text pair splits between them. At 0.95 a single reading was
        // already shouting; two of them side by side took a third of the bar.
        font.pixelSize: imageVisible?((parent.height/2)*0.95):(parent.height*0.62);
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
                /*
                 * Fade only. Animating width assigns to it, and that drops the
                 * width binding for good - after which the indicator keeps
                 * whatever the animation left, and its icon and its reading are
                 * laid out against a width that matches neither. Nor can the
                 * binding simply be restored afterwards: indicatorImage.width
                 * is itself bound to indicatorRoot.width whenever the text is
                 * shown, so every width at or above contentWidth is a stable
                 * fixed point and re-binding freezes the wrong one. The Row
                 * skips an invisible item, so the collapse the width animation
                 * used to draw is not needed for the item to get out of the way.
                 */
                ParallelAnimation {
                    NumberAnimation { target: indicatorImage; properties: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                    NumberAnimation { target: indicatorText; properties: "opacity"; from: 1.0; to: 0.0; duration: 200 }
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
                }
            }
        }
    ]
}
