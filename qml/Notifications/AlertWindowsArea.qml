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
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1
import LunaNext.Shell.Notifications 0.1

import "../Utils"

Rectangle {
    id: rootAlertsArea
    height: maxHeight
    property int maxHeight: 0

    color: "black"

    WindowModel {
        id: listPopupAlertsModel
        windowTypeFilter: WindowType.PopupAlert
    }
    WindowModel {
        id: listBannerAlertsModel
        windowTypeFilter: WindowType.BannerAlert
    }

    Component {
        id: alertComponent
        Item {
            id: alertItem

            y: rootAlertsArea.height - height
            width: rootAlertsArea.width
            height: window ? window.height : 0
            onHeightChanged: computeNewRootHeight();

            children: [ window ]

            Component.onCompleted: {
                if( window ) {
                    window.parent = alertItem;

                    /* This resizes only the quick item which contains the child surface but
                                     * doesn't really resize the client window */
                    window.anchors.left = alertItem.left;
                    window.anchors.right = alertItem.right;
                    window.y = 0;
                }
            }
        }
    }

    function computeNewRootHeight()
    {
        var i=0;
        var newMaxHeight = 0;
        var currentMaxHeight = 0;
        for( i=0; i < listPopupAlertsModel.count; ++i ) {
            currentMaxHeight = listPopupAlertsModel.getByIndex(i).height;
            if( currentMaxHeight > newMaxHeight )
                newMaxHeight = currentMaxHeight;
        }
        for( i=0; i < listBannerAlertsModel.count; ++i ) {
            currentMaxHeight = listBannerAlertsModel.getByIndex(i).height;
            if( currentMaxHeight > newMaxHeight )
                newMaxHeight = currentMaxHeight;
        }

        rootAlertsArea.maxHeight = newMaxHeight;
    }

    Repeater {
        id: repeaterAlerts

        anchors.left: rootAlertsArea.left
        anchors.right: rootAlertsArea.right
        anchors.bottom: rootAlertsArea.bottom
        model: listPopupAlertsModel
        delegate: alertComponent

        onItemAdded: {
            if( item.height > rootAlertsArea.maxHeight )
                rootAlertsArea.maxHeight = item.height;
        }
        onItemRemoved: {
            computeNewRootHeight();
        }
    }
    Repeater {
        id: repeaterBanners

        anchors.left: rootAlertsArea.left
        anchors.right: rootAlertsArea.right
        anchors.bottom: rootAlertsArea.bottom
        model: listBannerAlertsModel
        delegate: alertComponent

        onItemAdded: {
            if( item.height > rootAlertsArea.maxHeight )
                rootAlertsArea.maxHeight = item.height;
        }
        onItemRemoved: {
            computeNewRootHeight();
        }
    }
}
