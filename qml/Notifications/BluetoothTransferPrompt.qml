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
 * "Receive a file?": a Bluetooth device wants to send one (Object Push).
 * Shown by BluetoothTransferPromptArea, which talks to bluetooth2; this is
 * only the dialog. ask() takes bluetooth2's request as it comes
 * ({"requestId", "name", "address", "fileName", "fileSize"}), answered()
 * gives it back with the user's answer, once.
 *
 * Saying nothing is saying no: after timeoutMs the prompt answers Decline
 * by itself, before BlueZ's agent stops waiting (the SIL refuses at 50 s,
 * obexd at 60 s). Accept takes a tap only armDelayMs (1 s) after the
 * question is shown, as the pairing prompt's Pair; Decline is never held
 * back. withdraw() takes the prompt away without an answer.
 */
Dialog {
    id: prompt

    //! The request on screen, null when none.
    readonly property var request: _request
    property int timeoutMs: 45000
    property int armDelayMs: 1000
    readonly property bool armed: _armed

    signal answered(var request, bool accept)

    property var _request: null
    property bool _armed: false

    readonly property string _sender: _request ? String(_request.name || _request.address || "A device") : ""
    readonly property real _contentWidth: prompt.contentWidth !== undefined
                                          ? prompt.contentWidth : prompt.dialogWidth - Units.gu(3.2)
    readonly property real _buttonWidth: Units.gu(26.0)
    property real _buttonGap: Units.gu(1.5)
    readonly property color _acceptColor: "#2aa100"

    // "9.2 KB": what a user reads, not the bytes.
    function sizeText(bytes) {
        var n = Number(bytes);
        if (!(n >= 0))
            return "";
        if (n < 1024)
            return n + " bytes";
        var units = ["KB", "MB", "GB"];
        var i = -1;
        do {
            n /= 1024;
            i++;
        } while (n >= 1024 && i < units.length - 1);
        return (n < 10 ? n.toFixed(1) : Math.round(n)) + " " + units[i];
    }

    title: "Receive a file?"
    titlePixelSize: FontUtils.sizeToPixels("large")
    message: _sender + " wants to send you a file over Bluetooth."
    messagePixelSize: FontUtils.sizeToPixels("medium")
    dialogWidth: Math.min(Units.gu(36), parent ? parent.width - Units.gu(2) : Units.gu(36))
    dialogHeight: fittedHeight
    visible: false

    function ask(request) {
        if (!request || request.requestId === undefined)
            return;
        _request = request;
        _armed = false;
        arming.restart();
        deadline.restart();
        open();
    }

    function withdraw() {
        deadline.stop();
        arming.stop();
        _armed = false;
        _request = null;
        if (opened)
            close();
    }

    function _answer(accept) {
        if (_request === null || (accept && !_armed))
            return;
        var request = _request;
        withdraw();
        answered(request, accept);
    }

    property Timer _arming: Timer {
        id: arming
        interval: prompt.armDelayMs
        onTriggered: prompt._armed = true
    }

    property Timer _deadline: Timer {
        id: deadline
        interval: prompt.timeoutMs
        onTriggered: prompt._answer(false)
    }

    // The file's name as the sender gave it - its words, not markup - and
    // its size.
    Text {
        objectName: "bluetoothTransferFile"
        width: prompt._contentWidth
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAnywhere
        textFormat: Text.PlainText
        text: prompt.request ? String(prompt.request.fileName || "") : ""
        color: "#292929"
        font.bold: true
        font.pixelSize: FontUtils.sizeToPixels("medium")
    }
    Text {
        objectName: "bluetoothTransferSize"
        width: prompt._contentWidth
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: prompt.request ? prompt.sizeText(prompt.request.fileSize) : ""
        color: "#5a5a5a"
        font.pixelSize: FontUtils.sizeToPixels("small")
    }

    Item {
        width: 1
        height: Math.max(0, prompt._buttonGap - 2 * parent.spacing)
    }
    DialogButton {
        objectName: "bluetoothTransferAccept"
        text: "Accept"
        enabled: prompt.armed
        opacity: enabled ? 1 : 0.4
        color: prompt._acceptColor
        fontcolor: "white"
        buttonWidth: prompt._buttonWidth
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: prompt._answer(true)
    }
    Item {
        width: 1
        height: Math.max(0, prompt._buttonGap - 2 * parent.spacing)
    }
    DialogButton {
        objectName: "bluetoothTransferDecline"
        text: "Decline"
        color: "white"
        fontcolor: "#292929"
        buttonWidth: prompt._buttonWidth
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: prompt._answer(false)
    }
}
