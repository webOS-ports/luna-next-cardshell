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
import LuneOS.Passcode 1.0

import "../Connectors"
import "Lockout.js" as Lockout

Item {
    id: pinPasswordLock

    property int  edgeOffset: Units.gu(11/10)
    property int  margin: Units.gu(6/10)
    property int  topOffset: Units.gu(4/10)
    //! Above and below the Cancel/Done row, about the room "Device Locked"
    //! has above it: 20 pixels on a tenderloin.
    property int  buttonSpacing: Units.gu(14/10)
    property bool isPINEntry: true

    //! What the attached keyboard's key faces are labelled with; see the PIN
    //! handling in Keys.onPressed.
    KeyboardService {
        id: keyboardService
    }
    property int  minPassLength: 4
    property bool enforceMinLength: false
    property string queuedTitle: ""
    property string queuedHint: ""

    //! Seconds until luna-authmanager takes passcodes again; see Lockout.js.
    property int lockoutLeft: 0
    readonly property bool lockedOut: lockoutLeft > 0

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

    width: Units.gu(320/10) + 2 * pinPasswordLock.edgeOffset
    height: buttonGrid.y + buttonGrid.height + pinPasswordLock.edgeOffset + margin + buttonSpacing;
    focus: true;

    BorderImage {
        source: "../images/popup-bg.png"
        width: parent.width;
        height: parent.height;
        //border { left: Units.gu(35/10); top: Units.gu(40/10); right: Units.gu(35/10); bottom: Units.gu(40/10) }
        border { left: 35; top: 40; right: 35; bottom: 40 }
        smooth: true
    }

    Text {
        id: titleText;
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("large") //18 //todo
        font.bold: true;
        color: "#FFF";
        anchors.horizontalCenter: parent.horizontalCenter
        y: pinPasswordLock.edgeOffset + pinPasswordLock.margin + pinPasswordLock.topOffset;

        text: "Device Locked";
    }

    PasswordField {
        id: passwordField;
        isPIN: isPINEntry;
        enabled: !pinPasswordLock.lockedOut
        width: Units.gu(320/10) - Units.gu(4/10);
        x: pinPasswordLock.edgeOffset + Units.gu(3/10)
        y: titleText.y + titleText.height + (pinPasswordLock.isPINEntry ? 0 : Units.gu(6/10))
    }

    PinPad {
        id: keyPad
        visible: pinPasswordLock.isPINEntry
        enabled: !pinPasswordLock.lockedOut
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
        width: Units.gu(320/10) - 2 * pinPasswordLock.margin
        x: pinPasswordLock.edgeOffset + pinPasswordLock.margin
        anchors.top: pinPasswordLock.isPINEntry ? keyPad.bottom : passwordField.bottom;
        anchors.topMargin: pinPasswordLock.buttonSpacing

        columns: 2
        rows: 1
        spacing: pinPasswordLock.margin + 1

        ActionButton {
            caption: "Cancel";
            width: Math.round(buttonGrid.width/buttonGrid.columns - pinPasswordLock.margin / 2)
            height: Math.round(Units.gu(4))
            onAction: canceled();
        }

        ActionButton {
            caption: "Done";
            affirmative: true
            width: Math.round(buttonGrid.width/buttonGrid.columns - pinPasswordLock.margin / 2)
            height: Math.round(Units.gu(4))
            active: !pinPasswordLock.lockedOut &&
                    passwordField.enteredText.length >= (enforceMinLength ? minPassLength : 1)
            onAction: {
                if(passwordField.enteredText.length > 0) {
                    submitPassword(passwordField.enteredText, pinPasswordLock.isPINEntry);
                }
            }
        }
    }


    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
    }

    function submitPassword(password, isPin) {
        if (lockedOut)
            return;
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
        else if (Lockout.secondsFrom(response) > 0) {
            startLockout(Lockout.secondsFrom(response));
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

    function startLockout(seconds) {
        queuedTitle = "";
        queuedHint = "";
        passwordField.clearAll();
        titleText.text = "Too many tries";
        lockoutLeft = seconds;
        passwordField.setHintText(Lockout.waitText(lockoutLeft));
    }

    // Counts down with the display on; while the device sleeps neither this
    // nor the daemon's monotonic clock moves, so the two stay together. The
    // daemon has the last word either way: a try it still refuses comes back
    // with the time left.
    Timer {
        id: lockoutTimer
        interval: 1000
        repeat: true
        running: pinPasswordLock.lockedOut
        onTriggered: {
            pinPasswordLock.lockoutLeft--;
            if (pinPasswordLock.lockedOut) {
                passwordField.setHintText(Lockout.waitText(pinPasswordLock.lockoutLeft));
            } else {
                titleText.text = "Device Locked";
                passwordField.setHintText(pinPasswordLock.isPINEntry ? "Enter PIN" : "Enter password");
            }
        }
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

        if (lockedOut)
            return;

        /*
         * A PIN typed on a physical keyboard whose digits are printed on letter
         * keys. On a Q25 the key labelled 1 is w, and reaching the digit needs
         * Alt - which is no way to enter a PIN, and the reason typing one here
         * produced letters.
         *
         * Nothing in maliit can help: this is the shell's own QML inside the
         * compositor, so there is no input method in the path at all and no
         * content type to read. The keyboard's profile says what the key faces
         * are labelled with, and keyboardService carries that here.
         *
         * Only for a PIN. A password may perfectly well contain a w.
         */
        if(isPINEntry) {
            var digit = keyboardService.digitForScanCode(event.nativeScanCode);
            if(digit !== "") {
                passwordField.keyInput(digit, true);
                return;
            }
        }

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
         } else if(event.key === Qt.Key_Backspace) {
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

    // Nothing outside connects to passwordSubmitted, so Enter on a hardware
    // keyboard did nothing: it submits as Done does.
    onPasswordSubmitted: (password, isPIN) => submitPassword(password, isPIN)
}
