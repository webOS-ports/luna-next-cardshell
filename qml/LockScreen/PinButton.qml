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
    property bool isPressed: false
    property string caption: ""
    property string imgSource: ""
    property bool active: true

    BorderImage {
        id: pressedBkg
        source: "../images/pin/pin-key-highlight.png"
        visible: isPressed;
        width: parent.width;
        height: parent.height;
        border { left: 10; top: 10; right: 10; bottom: 10 }
    }

    Text {
        id: buttonText
        text: caption
        visible: caption != ""  && !buttonImg.visible;
        anchors.centerIn: parent
        color: "#FFF";
        font.bold: true;
        font.pixelSize: 30
        font.family: "Prelude"
        font.capitalization: Font.AllUppercase
    }

    Image {
        id: buttonImg
        source: imgSource
        visible: imgSource != "";
        anchors.centerIn: parent
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
            action(caption)
        }
    }

    signal action(string text)
}

