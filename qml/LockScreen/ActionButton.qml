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

import QtQuick 2.1
import LunaNext.Common 0.1

Item {
    property bool   isPressed: false
    property bool   active: true
    property string caption: "Button"
    property bool   affirmative: false
    property bool   negative:    false
    property real   inactiveOpacity: 0.70

    width:  Units.gu(200/8);
    height:  Units.gu(40/8);

    BorderImage {
        id: pressedBkg
        source: affirmative ? ( !isPressed ? "../images/pin/button-green.png" : "../images/pin/button-green-press.png") :
                 ( negative ? ( !isPressed ? "../images/pin/button-red.png"   : "../images/pin/button-red-press.png")   :
                              ( !isPressed ? "../images/pin/button-black.png" : "../images/pin/button-black-press.png")  )
        visible: true;
        width: parent.width;
        height: parent.height;
        border { left: Units.gu(10/8); top: Units.gu(10/8); right: Units.gu(10/8); bottom: Units.gu(10/8) }
        opacity: active ? 1.0 : inactiveOpacity
		smooth: true
		//fillMode: Image.PreserveAspectFit
    }

    Text {
        id: buttonText
        text: caption
        anchors.centerIn: parent
        color: "#FFF";
        font.bold: true;
        font.pixelSize: FontUtils.sizeToPixels("medium") //16
        font.family: "Prelude"
        opacity: active ? 1.0 : inactiveOpacity
    }

    MouseArea {
        id: mouseArea
        enabled: true;
        anchors.fill: parent
        onPressAndHold:  setPressed(true);
        onPressed: { mouse.accepted = true; setPressed(true); }
        onReleased: {setPressed(false);}
        onExited: {setPressed(false);}
        onCanceled: {setPressed(false);}
        onClicked: {
            actionPerformed()
         }
    }

    function setPressed (pressed) {
        if(active) {
            isPressed = pressed;
        }
    }

    function actionPerformed () {
        if(active) {
            action()
        }
    }

    signal action()
}
