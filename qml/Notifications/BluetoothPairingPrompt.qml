/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import LunaNext.Common 0.1
import LuneOS.Components 1.0

/*
 * What a Bluetooth pairing asks of the user, as the shell shows it: a code
 * to compare, a pairing to allow, a PIN or passkey to type, a code to type
 * on the other device - and that a pairing did not work.
 *
 * Shown by BluetoothPairingPromptArea, which holds LuneOS.Bluetooth's agent;
 * this is only the dialog. The question comes with the agent's request,
 * which takes the answer: accept() (with the PIN or passkey typed) or
 * reject(). A code to type on the other device has no request: the device
 * says when it is done, and the dialog only goes.
 *
 *     prompt.ask("confirmation", {"name": "herrie-desktop", ...}, "042201", request)
 *     prompt.withdraw()          // the pairing ended: the question goes
 *     prompt.fail(device)        // it did not work: say so
 *
 * Pair (or Allow) only takes a tap armDelayMs (1 s) after a question is
 * shown, and again after each new one, as UsbDebuggingPrompt's Allow: a tap
 * already on its way cannot pair a device the user has not seen. Cancel is
 * never held back. Tapping outside does nothing: Dialog blocks the page.
 */
Dialog {
    id: prompt

    //! What is asked: "confirmation", "authorization", "pinCode", "passkey",
    //! "displayPasskey", "displayPinCode", "failed", or "" when nothing is.
    readonly property string kind: _kind
    //! The device asking: {"name", "address"}.
    readonly property var device: _device
    //! The code shown, for "confirmation" and the "display" kinds.
    readonly property string code: _code
    //! How long after each question Pair waits before it takes a tap.
    property int armDelayMs: 1000
    readonly property bool armed: _armed

    property string _kind: ""
    property var _device: null
    property string _code: ""
    property var _request: null
    property bool _armed: false

    readonly property string _name: _device && _device.name ? String(_device.name)
                                    : (_device && _device.address ? String(_device.address) : "the device")
    readonly property bool _typing: _kind === "pinCode" || _kind === "passkey"
    readonly property bool _showsCode: _kind === "confirmation" || _kind === "displayPasskey"
                                       || _kind === "displayPinCode"
    readonly property bool _asksYesNo: _kind === "confirmation" || _kind === "authorization" || _typing
    // A passkey is six digits at most (BlueZ: 0-999999); a PIN up to 16
    // characters of any kind, though devices mostly use digits.
    readonly property int _maxLength: _kind === "passkey" ? 6 : 16

    readonly property real _contentWidth: prompt.contentWidth !== undefined
                                          ? prompt.contentWidth : prompt.dialogWidth - Units.gu(3.2)
    readonly property real _buttonWidth: Units.gu(26.0)
    property real _buttonGap: Units.gu(1.5)
    // As UsbDebuggingPrompt: green for going ahead, the light button for
    // Cancel, which destroys nothing.
    readonly property color _pairColor: "#2aa100"
    readonly property color _cancelColor: "white"
    readonly property color _cancelTextColor: "#292929"

    title: _kind === "failed" ? "Pairing failed" : "Bluetooth pairing"
    titlePixelSize: FontUtils.sizeToPixels("large")
    message: _message()
    messagePixelSize: FontUtils.sizeToPixels("medium")
    dialogWidth: Math.min(Units.gu(36), parent ? parent.width - Units.gu(2) : Units.gu(36))
    dialogHeight: fittedHeight
    keepClearOfKeyboard: _typing
    visible: false

    function _message() {
        switch (_kind) {
        case "confirmation":
            return _name + " wants to pair. Pair if it shows this code too:";
        case "authorization":
            return _name + " wants to pair with this device.";
        case "pinCode":
            return "Enter the PIN for " + _name + ". Try 0000 or 1234 if it has none of its own.";
        case "passkey":
            return "Enter the passkey " + _name + " shows.";
        case "displayPasskey":
        case "displayPinCode":
            return "Type this code on " + _name + ":";
        case "failed":
            return "Pairing with " + _name + " did not work. Check the code and try again.";
        }
        return "";
    }

    function ask(kind, device, code, request) {
        // A question still open goes unanswered: the agent dropped it for
        // this one.
        _kind = kind;
        _device = device;
        _code = code === undefined || code === null ? "" : String(code);
        _request = request === undefined ? null : request;
        field.text = "";
        _armed = false;
        arming.restart();
        open();
        if (_typing)
            field.textInput.forceActiveFocus();
    }

    // The pairing ended, answered or not: what is on screen for it goes.
    // A "failed" note stays, so a pairing that ended badly is read.
    function withdraw() {
        if (_kind === "failed")
            return;
        _reset();
    }

    function fail(device) {
        _kind = "failed";
        _device = device;
        _code = "";
        _request = null;
        arming.stop();
        _armed = true;
        open();
    }

    function _reset() {
        arming.stop();
        _armed = false;
        _kind = "";
        _device = null;
        _code = "";
        _request = null;
        field.text = "";
        if (opened)
            close();
    }

    function _pair() {
        if (!_armed || !_asksYesNo)
            return;
        var request = _request;
        var value = _typing ? field.typedText() : undefined;
        if (_typing && value === "")
            return;
        _reset();
        if (request)
            request.accept(value);
    }

    function _cancel() {
        var request = _request;
        _reset();
        if (request)
            request.reject();
    }

    property Timer _arming: Timer {
        id: arming
        interval: prompt.armDelayMs
        onTriggered: prompt._armed = true
    }

    // The code, large and bold, to compare or to type on the other device.
    Text {
        objectName: "bluetoothPairingCode"
        visible: prompt._showsCode
        width: prompt._contentWidth
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: prompt.code
        color: "#292929"
        font.bold: true
        font.pixelSize: FontUtils.sizeToPixels("x-large")
        font.letterSpacing: Units.gu(0.3)
    }

    Row {
        visible: prompt._typing
        anchors.horizontalCenter: parent.horizontalCenter
        DialogLineInput {
            id: field
            objectName: "bluetoothPairingField"
            width: prompt._buttonWidth
            // In its row: DialogLineInput lifts itself two grid units.
            anchors.verticalCenterOffset: 0
            inputMethodHints: Qt.ImhNoPredictiveText
                              | (prompt.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhPreferNumbers)
            textInput.maximumLength: prompt._maxLength
            // A passkey is a number: anything else typed is dropped.
            onTextChanged: {
                if (prompt.kind !== "passkey")
                    return;
                var only = text.replace(/[^0-9]/g, "");
                if (only !== text)
                    text = only;
            }
            onAccepted: prompt._pair()
        }
    }

    Item {
        width: 1
        height: Math.max(0, prompt._buttonGap - 2 * parent.spacing)
    }
    DialogButton {
        objectName: "bluetoothPairingPair"
        visible: prompt._asksYesNo
        text: prompt.kind === "authorization" ? "Allow" : "Pair"
        enabled: prompt.armed && (!prompt._typing || field.text !== "")
        opacity: enabled ? 1 : 0.4
        color: prompt._pairColor
        fontcolor: "white"
        buttonWidth: prompt._buttonWidth
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: prompt._pair()
    }
    Item {
        visible: prompt._asksYesNo
        width: 1
        height: Math.max(0, prompt._buttonGap - 2 * parent.spacing)
    }
    DialogButton {
        objectName: "bluetoothPairingCancel"
        text: prompt.kind === "failed" ? "OK" : (prompt._asksYesNo ? "Cancel" : "Close")
        color: prompt._cancelColor
        fontcolor: prompt._cancelTextColor
        buttonWidth: prompt._buttonWidth
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: prompt._cancel()
    }
}
