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
import LunaNext 0.1

Item {
    id: cardDelegateContainer

    // this is the card window instance wrapping the window container
    property variant cardWindow

    // this defines the size the card should have
    property alias cardWidth: cardDelegateContainer.width
    property alias cardHeight: cardDelegateContainer.height

    property bool isCurrent

    signal switchToMaximize()
    signal destructionRequest()

    property bool deleteCardWindowOnDestruction: false

    scale:  isCurrent ? 1.0: 0.9

    BorderImage {
        source: Qt.resolvedUrl("../images/card-shadow-tile.png");
        //sourceSize: Qt.size(87,87);

        anchors.centerIn: cardWindowWrapper
        width: cardWindowWrapper.width+2*30
        height: cardWindowWrapper.height+2*30

        border { left: 30; top: 30; right: 30; bottom: 30 }
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch

    }

    Item {
        id: cardWindowWrapper

        children: [ cardWindow ]

        anchors.fill: parent

        Component.onCompleted: {
            cardWindow.parent = cardWindowWrapper;
            cardWindow.anchors.fill = cardWindowWrapper;
            cardWindow.visible = true;
        }
        Component.onDestruction: {
            if( cardWindow )
            {
                cardWindow.visible = false;
                cardWindow.anchors.fill = undefined;
                cardWindow.parent = null;
            }
        }
    }

    Behavior on scale {
        NumberAnimation { duration: 100 }
    }

    onIsCurrentChanged: if(cardWindow) cardWindow.setCurrentCardState(isCurrent);

    // Delayed destruction for the cardWindow instance, to avoid problems
    // with evaluation of properties that depend on it
    Component.onDestruction: if(deleteCardWindowOnDestruction && cardWindow) cardWindow.destroy();
}
