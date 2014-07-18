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

MenuListEntry {
    id: rotationElement
    property int    ident:         0
    property alias  modeText:      rotationLock.text
    property bool   locked:        false
    property bool   delayUpdate:   false
    property string newText:       ""
    property bool   newLockStatus: false

    property int iconSpacing : 4
    property int rightMarging: 8

    content:
        Item {
        width: rotationElement.width

            Text {
            id: rotationLock
                x: ident;
                anchors.verticalCenter: parent.verticalCenter
                // text: runtime.getLocalizedString("Turn on Rotation Lock");
                text: "Turn on Rotation Lock"
                color: "#FFF";
                font.bold: false;
                font.pixelSize: 18
                font.family: "Prelude"
            }

            Image {
                id: lockIndicatorOn
                visible: !locked
                x: parent.width - width - iconSpacing - rightMarging
                anchors.verticalCenter: parent.verticalCenter

                source: "../../images/statusbar/icon-rotation-lock.png"
             }

            Image {
                id: lockIndicatorOff
                visible: locked
                x: parent.width - width - iconSpacing - rightMarging
                anchors.verticalCenter: parent.verticalCenter

                source: "../../images/statusbar/icon-rotation-lock-off.png"
             }
        }
}
