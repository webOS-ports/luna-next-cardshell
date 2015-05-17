/*
 * Copyright (C) 2015 Christophe Chapuis <chris.chapuis@gmail.com>
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

Item {
    id: freshNewItemsPopups

    property ListModel popupModel: ListModel {
        id: freshNewItemsModel
    }

    clip: true

    Rectangle {
        color: "black"
        anchors.fill: parent
    }

    function getIconUrlOrDefault(path) {
        var mypath = path.toString();
        if (mypath.length === 0)
        {
            return Qt.resolvedUrl("../images/default-app-icon.png");
        }
        
        if(mypath.slice(-1) === "/")
        {
            mypath = mypath + "icon.png"
        }
        return mypath
    }


    Repeater {
        model: freshNewItemsModel
        delegate:Rectangle {
            id: itemDelegate
            color: "black"
            width: freshNewItemsPopups.width
            height: freshNewItemsPopups.height
            y: Units.gu(3)

            property int delegateIndex: index

            Row {
                anchors.fill: parent
                spacing: Units.gu(0.8)
                Image {
                    id: freshItemIcon
                    height: parent.height
                    width: parent.height
                    source: getIconUrlOrDefault(object.iconUrl)
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    height: parent.height
                    width: parent.width - freshItemIcon.width
                    text: object.title.length>0 ? object.title : object.body
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    font.bold: true
                    color: "white"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }

            SequentialAnimation {
                id: slideItemAnimation
                running: false

                NumberAnimation {
                    target: itemDelegate
                    property: "y"; to: 0; duration: 500; easing.type: Easing.InOutQuad
                }
                PauseAnimation { duration: 1500 }
                ScriptAction {
                    script: freshNewItemsModel.remove(delegateIndex);
                }
            }

            onDelegateIndexChanged: {
                if( delegateIndex === 0 )
                    slideItemAnimation.start();
            }
            Component.onCompleted: {
                if( delegateIndex === 0 )
                    slideItemAnimation.start();
            }
        }
    }
}

