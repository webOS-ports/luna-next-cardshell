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
    property bool   connected:      false
    property int    cod:            0
    property string address:        ""
    property string connStatus:     ""
    property string status:         ""

    property int iconSpacing : 4
    property int rightMarging: 8

    Item {
        anchors.fill: parent
        Text {
            id: mainText
            anchors.verticalCenter: parent.verticalCenter
            text: name;
            horizontalAlignment: Text.AlignLeft
            width: parent.width - check.width - rightMarging - iconSpacing - 5
            elide: Text.ElideRight;
            color: "#FFF";
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
            font.pixelSize: 10
            font.family: "Prelude"
            font.capitalization: Font.AllUppercase
        }
    }

    Image {
        id: check
        x: parent.width - width - iconSpacing - rightMarging
        anchors.verticalCenter: parent.verticalCenter
        visible: connected
        source: "../../images/statusbar/system-menu-popup-item-checkmark.png"
    }
}
