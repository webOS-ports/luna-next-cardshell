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
import LunaNext.Shell 0.1s
import LunaNext.Compositor 0.1
import "Utils"

Item {
    property QtObject compositorInstance:compositor

    // it looks like this QML Item will never be really destroyed when we change the
    // source of the parent Loader. Therefore, to avoid having conflicts when creating or
    // removing windows, we just disable the signal handler when the first use app is finished.
    property bool ignoreSignals: false

    Connections {
        target: ignoreSignals?null:compositorInstance
        onWindowAdded: __handleWindowAdded(window)
        onWindowRemoved: __handleWindowRemoved(window)
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
    }

    FocusScope {
        id: childWrapperFocus

        property Item childWrapper: childWrapper
        anchors.fill: parent;

        // A simple container, to facilite the wrapping of the first use app
        Item {
            id: childWrapper
            property Item wrappedChild

            anchors.fill: parent;

            function setWrappedChild(window) {
                childWrapper.wrappedChild = window;
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
                else {
                    childWrapper.children = [];
                    childWrapperFocus.focus = false;
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

    function __handleWindowAdded(window) {
        // Bind the container with its app window
        childWrapperFocus.childWrapper.setWrappedChild(window);
    }

    function __handleWindowRemoved(window) {
        childWrapperFocus.childWrapper.setWrappedChild(null);
        ignoreSignals = true;
    }
}
