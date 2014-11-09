/*
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
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

/* this is not a perfect inverted mouse area, but that'll do for testing */
MouseArea {
    property Item sensingArea
    z: -1 // behind all the brothers;

    Component.onCompleted: {
        // extend the MouseArea to make it cover all the sensing area
        // convert position of card
        var newPos = mapFromItem(sensingArea, 0, 0, sensingArea.width, sensingArea.height);
        anchors.fill = undefined;
        x = newPos.x;
        y = newPos.y;
        width = newPos.width;
        height = newPos.height;
    }
}
