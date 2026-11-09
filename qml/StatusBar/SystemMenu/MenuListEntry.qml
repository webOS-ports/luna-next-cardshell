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
import LunaNext.Common 0.1

Rectangle {
    id: itemRect
    width: parent.width
    height: Units.gu(4.2) 
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
        width: parent.width - Units.gu(0.8); 
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        border { left: 19; top: 0; right: 19; bottom: 0 }
        anchors.leftMargin: Units.gu(0.5)
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        anchors.rightMargin: Units.gu(0.5)
    }

    Item {
        children: [content]
        y: (itemRect.height - content.height)/2
    }

    MouseArea {
        id: mouseArea
        enabled: selectable;
        anchors.fill: parent
        /*
         * A hold counts when the hold timer fires with the finger still where
         * it went down, as a hold on a row of the Wi-Fi app does (TapHandler's
         * long press). These rows sit in the menu's Flickable: a finger that
         * has moved past the drag distance first is a scroll, and the
         * Flickable takes it (which cancels this area); one that moved less
         * but some is still not counted, so a slow start of a scroll does not
         * open anything either.
         *
         * With a pressAndHold handler MouseArea sends no clicked() for the
         * release that ends a hold, so a held row never also does its tap.
         */
        property bool moved: false
        property point pressPoint

        onPressAndHold: {
            setSelected(true);
            if (!moved && selectable)
                itemRect.held();
        }
        onPressed: function(mouse) {
            mouse.accepted = true;
            moved = false;
            pressPoint = Qt.point(mouse.x, mouse.y);
            setSelected(true);
        }
        onPositionChanged: function(mouse) {
            if (Math.abs(mouse.x - pressPoint.x) > Qt.styleHints.startDragDistance
                    || Math.abs(mouse.y - pressPoint.y) > Qt.styleHints.startDragDistance)
                moved = true;
        }
        onReleased: setSelected(false)
        onExited: setSelected(false)
        onCanceled: setSelected(false)
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
    // Pressed and held still: what the row offers besides its tap
    signal held()

    signal flickOverride(bool override)
}
