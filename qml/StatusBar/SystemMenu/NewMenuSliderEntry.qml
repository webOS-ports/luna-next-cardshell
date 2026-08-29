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

import QtQuick 2.0
import LunaNext.Common 0.1

// A "Label: N%" line with a full-width slider underneath, as used by
// the Volume and Screen tabs of the New Device Menu.
MenuListEntry {
    id: sliderEntry

    property string label: ""
    property alias sliderValue: slider.setValue
    property bool active: true
    property int ident: Units.gu(1.8)

    signal adjusted(real value, bool done)

    selectable: false
    height: Units.gu(9.4)

    content: Item {
        width: sliderEntry.width
        height: sliderEntry.height

        Text {
            x: ident
            y: Units.gu(1.4)
            text: sliderEntry.label + ": " + Math.round(slider.setValue * 100) + "%"
            color: "#FFF"
            font.bold: false
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.family: "Prelude"
        }

        Slider {
            id: slider
            x: ident + Units.gu(1)
            width: sliderEntry.width - 2 * (ident + Units.gu(1))
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Units.gu(1)
            active: sliderEntry.active

            // legacy Mojo-style glossy blue slider, like the original patch
            trackImageSource: "../../images/statusbar/devicemenu/slider-track.png"
            progressImageSource: ""
            handleImageSource: "../../images/statusbar/devicemenu/slider-button.png"
            trackHeight: Units.gu(0.7)
            handleSize: Units.gu(3.4)
            railBorderWidth: 3

            onValueChanged: sliderEntry.adjusted(value, done)
            onSetFlickOverride: flickOverride(override)
        }
    }
}
