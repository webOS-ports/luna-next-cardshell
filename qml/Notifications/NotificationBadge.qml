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

/*
 * The count badge legacy webOS put on the icon of a dashboard holding more
 * than one notification (Mojo's .dashboard-newitem, Enyo's .dashboard-count).
 *
 * Drawn rather than taken from dashboard-newitem-badge.png, which is only
 * 25x28 and would blur at today's densities. The colours are that image's
 * (Enyo 1, as in enyo-1.0-ports): a dark ring, a pale blue top rim, glass
 * from #517DA4 down to #345069, a hard horizon at the middle to #233747,
 * rising again to #416483 and a #4E86AF bottom rim. The body is 20 of the
 * image's 28 px; set height to the body's height.
 *
 * Grows sideways for counts of two digits and more, as the stretchable
 * original did.
 */
Rectangle {
    id: badge

    property int count: 0

    readonly property real _ring: Math.max(1, height / 20)

    width: Math.max(height, label.implicitWidth + height * 0.6)
    radius: height / 2
    color: "#CC040404"

    Rectangle {
        anchors.fill: parent
        anchors.margins: badge._ring
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#A8D1F6" }
            GradientStop { position: 0.06; color: "#517DA4" }
            GradientStop { position: 0.49; color: "#345069" }
            GradientStop { position: 0.50; color: "#233747" }
            GradientStop { position: 0.94; color: "#416483" }
            GradientStop { position: 1.00; color: "#4E86AF" }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: badge.count
        color: "white"
        font.bold: true
        font.pixelSize: badge.height * 0.7
    }
}
