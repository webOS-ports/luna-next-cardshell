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

/*!
 * \brief Turns the flashlight on and off.
 *
 * Shown only where there is one - see SystemMenu.qml.
 */
MenuListEntry {
    id: flashlightElement

    property int ident: 0
    //! What torchd last reported; see Connectors/TorchService.qml.
    property bool on: false

    content:
        Item {
            width: flashlightElement.width

            Text {
                x: ident
                anchors.verticalCenter: parent.verticalCenter
                text: flashlightElement.on ? "Turn off Flashlight"
                                           : "Turn on Flashlight"
                color: "#FFF"
                font.bold: false
                font.pixelSize: FontUtils.sizeToPixels("medium")
                font.family: "Prelude"
            }
        }
}
