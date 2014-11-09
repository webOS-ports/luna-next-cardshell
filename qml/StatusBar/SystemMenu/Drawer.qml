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

Column {
	id: drawer
        property MenuListEntry drawerHeader
        property Item drawerBody

        property bool active: true

        property int  maxViewHeight: 0

        state: "DRAWER_CLOSED"

        signal drawerOpened()
        signal drawerClosed()
        signal requestViewAdjustment(int offset)
        signal drawerFinishedClosingAnimation()

        function isOpen() {
            return (drawer.state == "DRAWER_OPEN");
        }

        function adjustViewIfNecessary() {
            if(maxViewHeight > 0) {
                var totalHeight = drawerHeader.height + body.childrenRect.height;

                if((drawer.y + totalHeight) > maxViewHeight) {
                    var offset = Math.min(((drawer.y + totalHeight) - maxViewHeight), drawer.y);
                    requestViewAdjustment(offset);
                }
            }
        }

        spacing: 0

        Rectangle {
        id: header
        width: parent.width
        height: drawerHeader.height
        color: "transparent"

        Item {
            width: parent.width
            children: drawerHeader
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent

            onPressed: { drawerHeader.setSelected(true); }
            onReleased: { drawerHeader.setSelected(false); }
            onExited: { drawerHeader.setSelected(false); }
            onCanceled: { drawerHeader.setSelected(false); }

            onClicked: {
                if(active) {
                     if (drawer.state == "DRAWER_CLOSED") {
                         open()
                     }
                     else if (drawer.state == "DRAWER_OPEN"){
                         close()
                     }
                     drawerHeader.actionPerformed()
                 }
             }
        }
    }

    Rectangle {
        id: body
        width: parent.width
        color: "transparent"
        clip: true
        children: { drawerBody }

        Behavior on height { NumberAnimation{ id: heightAnim; duration: 200} }
    }

    states:[
        State {
            name: "DRAWER_OPEN"
            PropertyChanges { target: body; height: body.childrenRect.height}
        },
        State {
            name: "DRAWER_CLOSED"
            PropertyChanges { target: body; height: 0}
        }
    ]

    transitions: [
        Transition {
            to: "*"
            NumberAnimation { target: body; properties: "height"; duration: 350; easing.type:Easing.OutCubic }
        }
    ]

    function close () {
        if(drawer.state == "DRAWER_CLOSED")
            return;

        drawer.state = "DRAWER_CLOSED"
        drawerClosed()
    }

    function open () {
        if(drawer.state == "DRAWER_OPEN")
            return;

        drawer.state = "DRAWER_OPEN"
        drawerOpened()
        adjustViewIfNecessary();
    }
}
