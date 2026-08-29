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

// One row of the New Device Menu: a title on the left and an
// uppercase status label ("ON"/"OFF"/"AUTO"/...) on the right,
// mirroring the palm-row/title/label layout of the legacy patch.
MenuListEntry {
    id: toggleEntry

    property string text: ""
    property string statusText: ""
    property int ident: Units.gu(1.8)
    property int indent: 0
    property bool active: true
    property bool showSpinner: false
    property bool spinning: false

    selectable: active
    height: Units.gu(5.2)

    content: Item {
        width: toggleEntry.width

        Text {
            id: titleText
            x: ident + indent
            anchors.verticalCenter: parent.verticalCenter
            text: toggleEntry.text
            color: toggleEntry.active ? "#FFF" : "#AAA"
            font.bold: false
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.family: "Prelude"
        }

        Spinner {
            width: Units.gu(3.2)
            height: Units.gu(3.2)
            x: titleText.x + titleText.width + Units.gu(1.8)
            anchors.verticalCenter: parent.verticalCenter
            on: toggleEntry.spinning && toggleEntry.showSpinner
        }

        Text {
            x: toggleEntry.width - width - Units.gu(1.4)
            anchors.verticalCenter: parent.verticalCenter
            text: toggleEntry.statusText
            horizontalAlignment: Text.AlignRight
            color: "#AAA"
            font.pixelSize: FontUtils.sizeToPixels("small")
            font.family: "Prelude"
            font.capitalization: Font.AllUppercase
        }
    }
}
