/*
 * Copyright (C) 2015 Alan Stice <alan@alanstice.com>
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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

MenuListEntry {
    id: powerElement

    property int ident: 0

    content:
        Item {
            width: powerElement.width

            Text {
                id: powerText
                x: ident;
                anchors.verticalCenter: parent.verticalCenter
                text: "Power"
                color: "#FFF";
                font.bold: false;
                font.pixelSize: FontUtils.sizeToPixels("medium") //18
                font.family: "Prelude"
            }
        }
}
