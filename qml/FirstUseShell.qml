/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext.Shell 0.1
import LunaNext.Compositor 0.1
import "Utils"
import "WindowManager"

Item {
    WindowModel {
        id: listCardsModel
        windowTypeFilter: WindowType.Card
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
    }

    Repeater {
        anchors.fill: parent
        model: listCardsModel

        delegate: FocusScope {
            id: childWrapperFocus
            anchors.fill: parent

            Item {
                id: childWrapper
                anchors.fill: parent
            }

            Component.onCompleted: {
                if( window ) {
                    window.parent = childWrapper;
                    childWrapper.children = [ window ];

                    /* This resizes only the quick item which contains the child surface but
                     * doesn't really resize the client window */
                    window.anchors.fill = childWrapper;

                    /* Resize the real client window to have the right size */
                    window.changeSize(Qt.size(childWrapper.width, childWrapper.height));

                    childWrapperFocus.focus = true;
                }
            }
        }
    }

    // Rounded corners
    RoundedItem {
        id: cornerStaticMask
        anchors.fill: parent
        visible: true
        cornerRadius: 20
    }

    OverlaysManager {
        id: overlaysManagerInstance
        anchors.fill: parent
        z: 4 // on top of everything (including fullscreen)
    }
}
