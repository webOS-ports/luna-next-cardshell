/*
 * Copyright (C) 2026 webOS Ports Project
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

import QtQuick
import QtQuick.Effects

// A halo around an item, drawn from a white (or tinted), blurred copy of the
// item. Put this next to the item and under it: the halo then also shows through
// the item's translucent parts, which a drop shadow does not do and which is what
// Qt5Compat's Glow did.
//
// A single blurred copy is too faint, so a few are stacked to set the strength.
Item {
    id: iconGlow

    // The item to draw the halo around, a sibling of this one
    property Item source

    // How far the halo reaches, in pixels, as Qt5Compat's Glow.radius did
    property real radius: 12

    property color color: "white"

    // Copies stacked on top of each other: the strength of the halo
    property int strength: 4

    // MultiEffect's blur runs from 0 to 1 over blurMax pixels (64 here); this puts
    // a radius in pixels onto that range with the halo matching Glow's width
    readonly property real blur: Math.min(1.0, iconGlow.radius * 0.0317)

    Repeater {
        model: iconGlow.strength

        MultiEffect {
            anchors.fill: iconGlow
            source: iconGlow.source
            autoPaddingEnabled: true
            // Colorizing a source brightened to white gives it one flat colour,
            // keeping its alpha
            colorization: 1.0
            colorizationColor: iconGlow.color
            brightness: 1.0
            blurEnabled: true
            blurMax: 64
            blur: iconGlow.blur
        }
    }
}
