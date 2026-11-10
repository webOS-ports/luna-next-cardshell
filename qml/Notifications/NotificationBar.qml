/*
 * Copyright (C) 2026 alan-morford <alan-morford@users.noreply.github.com>
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
 * The bar every entry in the phone notification area sits on, in legacy
 * webOS's dashboard look.
 *
 * The colours are webOS 2.2.4's, measured off Mojo's 1.5x
 * dashboard-container-sprite.png composited on black: a vertical gradient
 * from #262626 to #383838, a 1 px #303030 line along the top and a 1 px
 * #4D4D4D highlight along the bottom, both following the rounded corners.
 * Pressed, the pill turns #616161 to #6E6E6E. The corners are rounded by a
 * sixth of an entry's height, a little tighter than the stock art's quarter.
 * The art was a fixed 52 px tall with fixed corners, so a dashboard that asks
 * for more height (dashHeight) keeps the corners of a standard entry:
 * cornerHeight, rather than a sixth of its own height.
 *
 * Shared by toasts (NotificationItem) and dashboards, which sit on it once WAM
 * has made their windows transparent.
 */
Item {
    id: bar

    property bool pressed: false
    // The height the corners are worked out from: a standard entry's.
    property real cornerHeight: height
    readonly property real radius: Math.min(height, cornerHeight) / 6

    // Bottom highlight: the base shape, of which only the lowest pixel shows.
    Rectangle {
        anchors.fill: parent
        radius: bar.radius
        color: bar.pressed ? "#6E6E6E" : "#4D4D4D"
    }
    // Top line: one pixel shorter, so the highlight shows below it.
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 1
        radius: bar.radius
        color: bar.pressed ? "#616161" : "#303030"
    }
    // The fill, inside both lines.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: bar.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: bar.pressed ? "#616161" : "#262626" }
            GradientStop { position: 1.0; color: bar.pressed ? "#6E6E6E" : "#383838" }
        }
    }
}
