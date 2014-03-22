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
    id: justTypeLauncher

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: justTypeLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: justTypeLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: justTypeLauncher; anchors.top: parent.top; anchors.bottom: parent.bottom }
            PropertyChanges { target: justTypeLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: justTypeLauncher; property: "visible" }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 150 }
            }
        }
    ]

    function setLauncherWindow(window) {
        window.parent = justTypeLauncher;
        justTypeLauncher.children = [ window ];

        /* This resizes only the quick item which contains the child surface but
         * doesn't really resize the client window */
        window.anchors.fill = justTypeLauncher;

        /* Resize the real client window to have the right size */
        window.changeSize(Qt.size(justTypeLauncher.width, justTypeLauncher.height));
    }
}
