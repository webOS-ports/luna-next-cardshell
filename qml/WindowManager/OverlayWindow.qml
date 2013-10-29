/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LunaNext 0.1

Item {
    id: overlayWindowItem

    state: "hidden"
    opacity: 0

    property Item overlaysManagerInstance
    anchors.top: overlaysManagerInstance.bottom

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: overlayWindowItem; anchors.top: overlaysManagerInstance.bottom; anchors.bottom: undefined }
            PropertyChanges { target: overlayWindowItem; opacity: 0 }
        },
        State {
            name: "visible"
            AnchorChanges { target: overlayWindowItem; anchors.top: undefined; anchors.bottom: overlaysManagerInstance.bottom }
            PropertyChanges { target: overlayWindowItem; opacity: 1 }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            ParallelAnimation {
                NumberAnimation { target: overlayWindowItem; properties: "opacity"; easing.type:Easing.InOutQuad; duration: 400 }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 300 }
            }
        }
    ]
}
