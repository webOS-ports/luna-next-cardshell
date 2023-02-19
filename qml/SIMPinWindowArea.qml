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
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

Item {
    id: simPinWindowAreaItem

    property bool simPinWindowPresent: listPinWindowModel.count>0
    property Item windowManagerInstance
    property Item __simPinWindow

    WindowModel {
        id: listPinWindowModel
//        windowTypeFilter: WindowType.Pin

        onRowsInserted: {
            appendPinWindow(listPinWindowModel.getByIndex(listPinWindowModel.count-1));
        }
    }

    function discardSIMPinWindow() {
        if( __simPinWindow ) compositor.closeWindowWithId(__simPinWindow.winId);
    }

    function appendPinWindow(window) {
        console.log("SIMPinWindowArea: adding " + window);

        __simPinWindow = window;
        window.parent = simPinWindowAreaItem;
        window.anchors.fill = simPinWindowAreaItem;
        /* Resize the real client window to have the right size */
        window.changeSize(Qt.size(simPinWindowAreaItem.width, simPinWindowAreaItem.height));

        windowManagerInstance.removeTapAction("discardSIMPinWindow"); // if any was registered, remove it
        windowManagerInstance.addTapAction("discardSIMPinWindow", discardSIMPinWindow, null)
    }
}
