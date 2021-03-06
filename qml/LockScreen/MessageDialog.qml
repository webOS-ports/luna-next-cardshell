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

Item {
    property int  edgeOffset: Units.gu(11/10) 
    property int  margin: Units.gu(6/10)
    property int  topOffset: Units.gu(4/10)

    property string dialogTitle: "Title"
    property string dialogMessage: "Message Body."
    property int    numberOfButtons: 3 // valid between 0 and 3

    property alias actionButton1: button1;
    property alias actionButton2: button2;
    property alias actionButton3: button3;

    signal button1Pressed();
    signal button2Pressed();
    signal button3Pressed();

    width: Units.gu(320/10) + Units.gu(2/10) * edgeOffset
    height: titleText.height + msgText.height + ((numberOfButtons > 0) ? (button1.height + button2.height + button3.height) : edgeOffset) + 2*edgeOffset + 4*margin + topOffset;

    id: dialog;

    function setupDialog(title, message, numButtons) {
         dialogTitle     = title;
         dialogMessage   = message;
         numberOfButtons = numButtons;
     }

    function setButton1(message, type) {
        setupButton(button1, message, type);
    }

    function setButton2(message, type) {
        setupButton(button2, message, type);
    }

    function setButton3(message, type) {
        setupButton(button3, message, type);
    }

    function setupButton (button, message, type) {
        button.caption = message;
        button.affirmative = (type === "affirmative");
        button.negative = (type === "negative");
        button.visible = (type !== "disabled");
    }

    function fade(fadeIn, fadeDuration) {
        fadeAnim.duration = fadeDuration;

        if(fadeIn) {
            opacity = 1.0;
        } else {
            opacity = 0.0;
        }
    }

    Behavior on opacity {
        NumberAnimation{ id: fadeAnim; duration: 300; }
    }

    onOpacityChanged: {
        if(opacity == 0.0) {
            visible = false;
         } else {
            visible = true;
        }
    }

    BorderImage {
        source: "../images/popup-bg.png"
        width: parent.width;
        height: parent.height;
        border { left: Units.gu(35/10); top: Units.gu(40/10); right: Units.gu(35/10); bottom: Units.gu(40/10) }
        smooth: true
    }

    Text {
        id: titleText;
        width: dialog.width - 2 * (edgeOffset + margin);
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("large")//18
        font.bold: true;
        wrapMode: Text.Wrap;
        color: "#FFF";
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignLeft;
        y: edgeOffset + margin + topOffset;

        text: dialogTitle;
    }

    Text {
        id: msgText;
        width: dialog.width - 2 * (edgeOffset + margin);
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("medium") //14
        font.bold: true;
        wrapMode: Text.Wrap;
        color: "#FFF";
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignLeft;
        y: titleText.y + titleText.height + margin;

        text: dialogMessage;
    }


    ActionButton {
        id: button1;
        caption: "Button 1";
        width: dialog.width - 2 * (edgeOffset + margin) - 1;
        height: visible ? Units.gu(52/10) : 0;
        x: edgeOffset + margin + Units.gu(1/10);
        y: msgText.y + msgText.height + margin;
        visible: numberOfButtons > 0;
        onAction: button1Pressed();
    }

    ActionButton {
        id: button2;
        caption: "Button 2";
        width: dialog.width - 2 * (edgeOffset + margin) - Units.gu(1/10);
        height: visible ? Units.gu(52/10) : 0;
        x: edgeOffset + margin + Units.gu(1/10);
        y: button1.y + button1.height
        visible: numberOfButtons > 1;
        onAction: button2Pressed();
    }

    ActionButton {
        id: button3;
        caption: "Button 3";
        width: dialog.width - 2 * (edgeOffset + margin) - Units.gu(1/10);
        height: visible ? Units.gu(52/10) : 0;
        x: edgeOffset + margin + Units.gu(1/10);
        y: button2.y + button2.height
        visible: numberOfButtons > 2;
        onAction: button3Pressed();
    }
}
