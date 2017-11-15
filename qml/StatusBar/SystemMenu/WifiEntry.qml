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

// Connman
import Connman 0.2

Item {
    property string name:           ""
    property int    strength:       0
    property int    securityType:   NetworkService.SecurityNone
    property string status:         ""
    property bool   connected:      false

    readonly property bool _statusInBold: state === "ipFailed"
    property string _statusString: {
        if((state === "userSelected") || (state === "associated") || (state === "associating")) {
            return "Connecting...";
        } else if(state === "ipFailed") {
            return "IP configuration failed";
        } else if(state === "associationFailed") {
            return "Association failed";
        } else {
            return "";
        }
    }
    readonly property int _signalBars: Math.floor(strength/25)

    property int iconSpacing : Units.gu(0.4)
    property int rightMarging: Units.gu(0.8)

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
            font.pixelSize: FontUtils.sizeToPixels("medium") //16
            font.family: "Prelude"
        }
        Text {
            id: statusText
            visible: status != ""
            y: mainText.y + mainText.baselineOffset + 1
            text: _statusString;
            color: "#AAA";
            font.bold: _statusInBold;
            font.pixelSize: FontUtils.sizeToPixels("x-small") //10
            font.family: "Prelude"
            font.capitalization: Font.AllUppercase
        }
    }

    Image {
        id: sigStrength
        x: parent.width - width - iconSpacing - rightMarging
        anchors.verticalCenter: parent.verticalCenter

        source: "../../images/statusbar/wifi-" + _signalBars + ".png"
        height: Units.gu(1.8) 
        width: Units.gu(2) 
    }

    Image {
        id: lock
        x: sigStrength.x - width - iconSpacing
        anchors.verticalCenter: parent.verticalCenter
        visible: securityType !== NetworkService.SecurityNone
        source: "../../images/statusbar/system-menu-lock.png"
        height: Units.gu(2.3)
        width: Units.gu(2) 
    }

    Image {
        id: check
        x: lock.x - width - iconSpacing
        anchors.verticalCenter: parent.verticalCenter
        visible: connected
        source: "../../images/statusbar/system-menu-popup-item-checkmark.png"
        height: Units.gu(2.3)
        width: Units.gu(3.1) 
    }
}
