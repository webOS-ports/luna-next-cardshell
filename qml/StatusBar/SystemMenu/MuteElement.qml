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
    id: muteElement
    property int    ident:         0
    property alias  muteText:      muteToggle.text
    property bool   mute:          false
    property bool   delayUpdate:   false
    property string newText:       ""
    property bool   newMuteStatus: false

    property int iconSpacing : 4
    property int rightMarging: 8

    content:
        Item {
        width: muteElement.width

            Text {
            id: muteToggle
                x: ident;
                anchors.verticalCenter: parent.verticalCenter
                //text: runtime.getLocalizedString("Mute Sound")
                text: "Mute Sound"
                color: "#FFF";
                font.bold: false;
                font.pixelSize: 18
                font.family: "Prelude"
            }

            Image {
                id: muteIndicatorOn
                visible: !mute
                x: parent.width - width - iconSpacing - rightMarging
                anchors.verticalCenter: parent.verticalCenter

                source: "../../images/statusbar/icon-mute.png"
             }

            Image {
                id: muteIndicatorOff
                visible: mute
                x: parent.width - width - iconSpacing - rightMarging
                anchors.verticalCenter: parent.verticalCenter

                source: "../../images/statusbar/icon-mute-off.png"
             }
        }
}
