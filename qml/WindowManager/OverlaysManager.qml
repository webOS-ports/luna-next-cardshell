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

import "../Utils"

Item {
    id: overlaysManagerItem

    WindowModel {
        id: listOverlaysModel
        windowTypeFilter: WindowType.Overlay

        onRowsInserted: {
            appendOverlayWindow(launcherListModel.get(launcherListModel.count-1).window);
        }
    }

    function dumpObject(object) {
        console.log("-> Dump of " + object);
        var _property
        for (_property in object) {
          console.log( "---> " + _property + ': ' + object[_property]+'; ' );
        }
    }

    function appendOverlayWindow(window) {
        console.log("OverlayManager: adding " + window);

        window.parent = overlaysManagerItem;
        window.anchors.bottom = overlaysManagerItem.bottom;
        window.anchors.horizontalCenter = overlaysManagerItem.horizontalCenter;
    }
}
