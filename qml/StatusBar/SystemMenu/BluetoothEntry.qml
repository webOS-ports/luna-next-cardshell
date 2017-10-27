/* @@@LICENSE
*
* Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
* Copyright (c) 2009-2013 LG Electronics, Inc.
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

Item {
    id: btEntryId

    property string name
    property bool   connected:          false
    property bool   connecting:         false
    property bool   lastConnectFailed:  false

    property int iconSpacing : Units.gu(0.4)
    property int rightMarging: Units.gu(0.8)

    Item {
        anchors.fill: parent
        Text {
            id: mainText
            anchors.verticalCenter: parent.verticalCenter
            text: name;
            horizontalAlignment: Text.AlignLeft
            width: parent.width - check.width - rightMarging - iconSpacing - Units.gu(0.5) 
            elide: Text.ElideRight;
            color: "#FFF";
            font.bold: false;
            font.pixelSize: Units.gu(1.6) //16
            font.family: "Prelude"
        }

        Text {
            id: statusText
            visible: btEntryId.connecting
            y: mainText.y + mainText.baselineOffset + 1
            text: btEntryId.connecting ? "Connecting..." : lastConnectFailed ? "Unable to connect" : "";
            color: "#AAA";
            font.pixelSize: Units.gu(1) //10
            font.family: "Prelude"
            font.capitalization: Font.AllUppercase
        }
    }

    Image {
        id: check
        x: parent.width - width - iconSpacing - rightMarging
        height: Units.gu(2.3)
        width: Units.gu(3.1)
        anchors.verticalCenter: parent.verticalCenter
        visible: connected
        source: "../../images/statusbar/system-menu-popup-item-checkmark.png"
    }
}
