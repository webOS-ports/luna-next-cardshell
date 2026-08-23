/* @@@LICENSE
*
* Copyright (C) 2013-2026 Herman van Hazendonk <github.com@herrie.org>
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

/*
 * One row of the SIM drawer: the label of the slot with its operator (or why
 * it has none) on the second line, and the signal bars on the right.
 */
Item {
    property string name:         ""
    property string operatorName: ""
    property string simStatus:    "simnotfound"
    property string registration: "noservice"
    property bool   present:      false
    property bool   powered:      false
    property int    bars:         0

    property int iconSpacing:  Units.gu(0.4)
    property int rightMarging: Units.gu(0.8)

    // Second line: whatever the user most needs to know about this slot right
    // now, which is the problem if there is one and the operator otherwise.
    readonly property string _statusString: {
        if (!present)
            return "No SIM";
        if (simStatus === "pinrequired")
            return "PIN required";
        if (simStatus === "pukrequired")
            return "PUK required";
        if (simStatus === "pinpermblocked")
            return "SIM blocked";
        if (simStatus === "siminvalid")
            return "SIM not valid";
        if (!powered)
            return "Off";
        if (registration === "roam" || registration === "roamblink")
            return operatorName.length > 0 ? operatorName + " - Roaming" : "Roaming";
        if (registration === "searching")
            return "Searching...";
        if (registration === "denied")
            return "Not allowed";
        if (registration === "noservice")
            return "No service";

        return operatorName;
    }

    readonly property bool _statusInBold: present && (simStatus === "pinrequired" ||
                                                      simStatus === "pukrequired" ||
                                                      simStatus === "pinpermblocked")

    Item {
        anchors.fill: parent

        Text {
            id: mainText
            anchors.verticalCenter: parent.verticalCenter
            text: name
            color: "#FFF"
            horizontalAlignment: Text.AlignLeft
            width: parent.width - sigStrength.width - rightMarging - 2 * iconSpacing - 5
            elide: Text.ElideRight
            font.bold: false
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.family: "Prelude"
        }

        Text {
            id: statusText
            visible: _statusString !== ""
            y: mainText.y + mainText.baselineOffset + 1
            width: mainText.width
            text: _statusString
            color: "#AAA"
            elide: Text.ElideRight
            font.bold: _statusInBold
            font.pixelSize: FontUtils.sizeToPixels("x-small")
            font.family: "Prelude"
            font.capitalization: Font.AllUppercase
        }
    }

    Image {
        id: sigStrength
        x: parent.width - width - iconSpacing - rightMarging
        anchors.verticalCenter: parent.verticalCenter

        source: "../../images/statusbar/network/rssi-" +
                (!present || !powered ? "error" : Math.max(0, Math.min(5, bars))) + ".png"
        height: Units.gu(1.8)
        width: Units.gu(2)
    }
}
