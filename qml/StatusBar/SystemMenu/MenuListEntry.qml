/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* LICENSE@@@ */

import QtQuick 2.0

Rectangle {
    id: itemRect
    width: parent.width
    height: 42
    color: "transparent"

    property Item content;
    property bool selectable: true
    property bool selected: false
    property bool forceSelected: false

    property int menuPosition:0 // 0 = middle, 1 = top, 2 = bottom

    BorderImage {
        id: highlight
        visible: (selectable && selected) || forceSelected
        source: menuPosition == 0 ? "../../images/menu-selection-gradient-default.png" :
                ( menuPosition == 1 ? "../../images/menu-selection-gradient-default.png" : "../../images/menu-selection-gradient-last.png")
        width: parent.width - 8;
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        border { left: 19; top: 0; right: 19; bottom: 0 }
        anchors.leftMargin: 5
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        anchors.rightMargin: 5
    }

    Item {
        children: [content]
        y: (itemRect.height - content.height)/2
    }

    MouseArea {
        id: mouseArea
        enabled: selectable;
        anchors.fill: parent
        onPressAndHold:  setSelected(true);
        onPressed: { mouse.accepted = true; setSelected(true); }
        onReleased: {setSelected(false);}
        onExited: {setSelected(false);}
        onCanceled: {setSelected(false);}
        onClicked: {
            actionPerformed()
         }
    }

    function setSelected (select) {

        if(selectable) {
            selected = select;
        }
    }

    function actionPerformed () {
        if(selectable) {
            action()
        }
    }

    signal action()

    signal flickOverride(bool override)
}
