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

Item {
    property string name
    property int    profileId:      0
    property int    signalBars:     0
    property string securityType:   ""
    property string connStatus:     ""
    property string status:         ""
    property bool   statusInBold:   false
    property bool   connected:      false

    property int iconSpacing : 4
    property int rightMarging: 3

    Item {
        anchors.fill: parent
        Text {
            id: mainText
            anchors.verticalCenter: parent.verticalCenter
            text: name; color: "#FFF";
            horizontalAlignment: Text.AlignLeft
            width: parent.width - sigStrength.width - check.width - lock.width - rightMarging - 3*iconSpacing - 5
            elide: Text.ElideRight;
            font.bold: false;
            font.pixelSize: 16
            font.family: "Prelude"
        }
        Text {
            id: statusText
            visible: status != ""
            y: mainText.y + mainText.baselineOffset + 1
            text: status;
            color: "#AAA";
            font.bold: statusInBold;
            font.pixelSize: 10
            font.family: "Prelude"
            font.capitalization: Font.AllUppercase
        }
    }

    Image {
        id: sigStrength
        x: parent.width - width - iconSpacing - rightMarging
        anchors.verticalCenter: parent.verticalCenter

        source: "../../images/statusbar/wifi-" + signalBars + ".png"
    }

    Image {
        id: lock
        x: sigStrength.x - width - iconSpacing
        anchors.verticalCenter: parent.verticalCenter
        visible: securityType != ""
        source: "../../images/statusbar/system-menu-lock.png"
    }

    Image {
        id: check
        x: lock.x - width - iconSpacing
        anchors.verticalCenter: parent.verticalCenter
        visible: connected
        source: "../../images/statusbar/system-menu-popup-item-checkmark.png"
    }
}
