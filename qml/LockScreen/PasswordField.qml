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
    property bool isPIN: false;
    property int maxPINLength:  30
    property int maxPassLength: 30
    property alias enteredText: inputField.text

    signal textFieldClicked();

    width: 320;
    height: isPIN ? inputField.height + 12: 50;

    function keyInput(keyText, isNumber) {
        if(inputField.text.length < (isPIN ? maxPINLength : maxPassLength)) {
            if(!isPIN || (isNumber)) {
                inputField.text = inputField.text.concat(keyText);
            }
        }
    }

    function clearAll() {
        inputField.text = "";
    }

    function deleteOne() {
        if(inputField.text.length > 0) {
            inputField.text = inputField.text.slice(0, inputField.text.length-1);
        }
    }

    function setHintText(hint) {
        hintText.text = hint;
    }

    BorderImage {
        visible: !isPIN;
        source: "../images/pin/password-lock-field.png"
        width: parent.width;
        height: parent.height;
        border { left: 30; top: 10; right: 30; bottom: 10 }
    }

    TextInput {
        id: inputField;
        width: parent.width - 16;
        anchors.verticalCenter: parent.verticalCenter;
        anchors.horizontalCenter: parent.horizontalCenter;
        echoMode: TextInput.PasswordEchoOnEdit;
        passwordCharacter: "•"
        cursorVisible: !isPIN;
        cursorPosition: text.length;
        activeFocusOnPress: false;
        focus: false;
        horizontalAlignment: isPIN ? TextInput.AlignHCenter : TextInput.AlignLeft;
        color: isPIN ? "#FFF" : "#000";
        font.bold: true;
        font.pixelSize: 18
        font.letterSpacing: 2
        font.family: "Prelude"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                textFieldClicked();
            }
        }
    }

    Text {
        id: hintText
        visible: inputField.text.length == 0;
        color: "#9C9C9C";
        font.pixelSize: 17
        font.family: "Prelude"
        width: parent.width - 20;
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: isPIN ? Text.AlignHCenter : Text.AlignLeft;

        text: isPIN ? "Enter PIN" : " Enter Password"; // Localize this
    }
}

