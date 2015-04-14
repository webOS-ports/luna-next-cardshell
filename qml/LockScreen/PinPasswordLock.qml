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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

Item {
    id: pinPasswordLock

    property int  edgeOffset: 11
    property int  margin: 6
    property int  topOffset: 4
    property bool isPINEntry: true
    property int  minPassLength: 4
    property bool enforceMinLength: false
    property string queuedTitle: ""
    property string queuedHint: ""

    signal canceled
    signal unlock

    signal requestFocusChange(bool focusRequest);
    signal passwordSubmitted(string password, bool isPIN);

    onCanceled: {
        passwordField.clearAll();
    }

    function setupDialog(isPIN, title, hintMessage, enforceLength, minLen) {
        isPINEntry = isPIN;
        titleText.text = title;
        enforceMinLength = enforceLength;
        minPassLength = minLen;
        passwordField.clearAll();
        passwordField.setHintText(hintMessage);
     }

    function queueUpTitle(newTitle, newHint) {
        queuedTitle = newTitle;
        queuedHint = newHint;
    }

    function fade(fadeIn, fadeDuration) {
        fadeAnim.duration = fadeDuration;

        if(fadeIn) {
            opacity = 1.0;
        } else {
            opacity = 0.0;
        }
    }

    width: 320 + 2 * pinPasswordLock.edgeOffset
    height: buttonGrid.y + buttonGrid.height + pinPasswordLock.edgeOffset + margin;
    focus: true;

    BorderImage {
        source: "../images/popup-bg.png"
        width: parent.width;
        height: parent.height;
        border { left: 35; top: 40; right: 35; bottom: 40 }
    }

    Text {
        id: titleText;
        font.family: "Prelude"
        font.pixelSize: 18
        font.bold: true;
        color: "#FFF";
        anchors.horizontalCenter: parent.horizontalCenter
        y: pinPasswordLock.edgeOffset + pinPasswordLock.margin + pinPasswordLock.topOffset;

        text: "Device Locked";
    }

    PasswordField {
        id: passwordField;
        isPIN: isPINEntry;
        width: 320 - 4;
        x: pinPasswordLock.edgeOffset + 3
        y: titleText.y + titleText.height + (pinPasswordLock.isPINEntry ? 0 : 6)
    }

    PinPad {
        id: keyPad
        visible: pinPasswordLock.isPINEntry
        x: pinPasswordLock.edgeOffset
        anchors.top: passwordField.bottom

        onKeyAction: {
            if(keyText == "\b") {
                // backspace key pressed
                passwordField.deleteOne();
            } else {
                passwordField.keyInput(keyText, true);
                if(queuedTitle != "") {
                    titleText.text = queuedTitle;
                    queuedTitle = "";
                }
                if(queuedHint != "") {
                    passwordField.setHintText(queuedHint);
                    queuedHint = "";
                }
            }
        }
    }

    Grid {
        id: buttonGrid
        width: 320 - 2 * pinPasswordLock.margin
        x: pinPasswordLock.edgeOffset + pinPasswordLock.margin
        anchors.top: pinPasswordLock.isPINEntry ? keyPad.bottom : passwordField.bottom;

        columns: 2
        rows: 1
        spacing: pinPasswordLock.margin + 1

        ActionButton {
            caption: "Cancel";
            width: buttonGrid.width/buttonGrid.columns - pinPasswordLock.margin / 2
            height:52
            onAction: canceled();
        }

        ActionButton {
            caption: "Done";
            affirmative: true
            width: buttonGrid.width/buttonGrid.columns - pinPasswordLock.margin / 2
            height:52
            active: passwordField.enteredText.length >= (enforceMinLength ? minPassLength : 1)
            onAction: {
                if(passwordField.enteredText.length > 0) {
                    submitPassword(passwordField.enteredText, pinPasswordLock.isPINEntry);
                }
            }
        }
    }


    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    function submitPassword(password, isPin) {
        service.call("luna://com.palm.systemmanager/matchDevicePasscode",
                     JSON.stringify({"passCode": password}),
                     handlePasscodeResult,
                     handleServiceError);
    }

    function handlePasscodeResult(message) {
        var response = JSON.parse(message.payload);

        console.log("response: " + message.payload);

        if (response.returnValue) {
            pinPasswordLock.unlock();
            passwordField.clearAll();
        }
        else {
            var title = "";
            var msg = "";

            if (pinPasswordLock.isPINEntry) {
                queueUpTitle("Device Locked", "Enter PIN");
                title = "PIN incorrect";
            }
            else {
                queueUpTitle("Device Locked", "Enter password");
                title = "Password incorrect";
            }

            setupDialog(pinPasswordLock.isPINEntry, title, msg, false, 0);
        }
    }

    function handleServiceError(message) {
        console.log("Service error: " + message);
    }

    function isValidKey(keyCode) {
        if(((keyCode >= Qt.Key_Escape) && (keyCode <= Qt.Key_Direction_R)) ||
           ((keyCode >= Qt.Key_Back) && (keyCode <= Qt.Key_unknown))     ) {
            // filter keys here
            return false;
        }

        return true;
    }

    function isNumber(keyCode) {
        if((keyCode >= Qt.Key_0) && (keyCode <= Qt.Key_9)) {
            return true;
        }

        return false;
    }

    Behavior on opacity {
        NumberAnimation{ id: fadeAnim;
                         duration: 300;
                         onStarted: {
                               if(opacity == 0.0) {
                               }  else {
                               }
                            }
                        }
    }

    onOpacityChanged: {
        if(opacity == 0.0) {
            if(!isPINEntry) {
                // faded away, clear focus
                requestFocusChange(false);
            } else {
                focus = false;
            }
            visible = false;
        } else if(opacity == 1.0) {
            if(!isPINEntry) {
                // faded in, request focus
                requestFocusChange(true);
            } else {
                focus = true;
            }
            visible = true;
        } else {
            visible = true;
        }
    }

    Keys.onPressed: {
        event.accepted = true;

        if(isValidKey(event.key)) {
             passwordField.keyInput(event.text, isNumber(event.key));
             if(queuedTitle != "") {
                 titleText.text = queuedTitle;
                 queuedTitle = "";
             }
             if(queuedHint != "") {
                 passwordField.setHintText(queuedHint);
                 queuedHint = "";
             }
         } else if(event.key == Qt.Key_Backspace) {
             passwordField.deleteOne();
         }
    }

    Keys.onReleased: {
        event.accepted = true;
    }

    Keys.onDeletePressed: {
        passwordField.deleteOne();
        event.accepted = true;
    }

    Keys.onEnterPressed: {
        event.accepted = true;
        if(passwordField.enteredText.length > 0) {
            passwordSubmitted(passwordField.enteredText, isPINEntry);
        }
    }

    Keys.onReturnPressed: {
        event.accepted = true;
        if(passwordField.enteredText.length > 0) {
            passwordSubmitted(passwordField.enteredText, isPINEntry);
        }
    }
}
