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
 * "Allow USB debugging?": what the shell asks when a computer that adbd
 * does not know yet wants in (org.webosports.service.devmode's
 * adbAuthRequests). It shows the computer's key fingerprint, an "Always
 * allow from this computer" box, and Deny and Allow.
 *
 * Shown by UsbDebuggingPromptArea, which talks to devmode; this is only the
 * dialog. It is built from LuneOS.Components' Dialog, DialogCheckBox and
 * DialogButton, and lives here because the shell is its only user.
 *
 *     UsbDebuggingPrompt {
 *         id: prompt
 *         onAnswered: (fingerprint, allow, always) =>
 *             service.call("luna://org.webosports.service.devmode/respondAdbAuth",
 *                          JSON.stringify({fingerprint, allow, always}))
 *     }
 *     ...
 *     prompt.ask(request.fingerprint, request.timeoutMs)
 *
 * Saying nothing is saying no: when timeoutMs runs out the prompt answers
 * Deny by itself (the service refuses at its own deadline too). Allow is
 * on top and Deny under it, 1.5 gu apart; tapping outside does nothing:
 * Dialog blocks the page behind it. withdraw() takes the prompt away without an
 * answer, for a question the service closed (the screen locked, adbd went).
 *
 * The box starts unticked for every question.
 *
 * Allow and the box only take a tap armDelayMs (1 s) after the question is
 * shown, and the wait starts again with every ask(): a tap already on its
 * way when the prompt appeared, or when another computer's question took
 * the place of the one on screen, cannot let that computer in. They are
 * drawn dimmed meanwhile. Deny is never held back.
 */
Dialog {
    id: prompt

    //! The question shown: the key's fingerprint, "" when none.
    readonly property string fingerprint: _fingerprint
    //! Milliseconds before it answers Deny by itself, from the last ask().
    property int timeoutMs: 30000
    //! Whether the user ticked "Always allow from this computer".
    readonly property bool always: alwaysBox.checked
    //! How long after each ask() Allow and the box wait before they take a tap.
    property int armDelayMs: 1000
    //! Whether Allow (and the box) take a tap yet.
    readonly property bool armed: _armed

    //! The user's answer, or Deny when the time ran out. Sent once a question.
    signal answered(string fingerprint, bool allow, bool always)

    property string _fingerprint: ""
    property bool _armed: false
    // How wide the fingerprint and the box may be: the Dialog's content
    // width, as its message has. A Dialog with contentWidth puts its
    // content 1 gu clear of the frame's visible edge, as legacy webOS's
    // ModalDialog did (herrie/dialog-legacy-insets); an older one has
    // none, and its content is the frame less 1.6 gu a side.
    readonly property real _contentWidth: prompt.contentWidth !== undefined
                                          ? prompt.contentWidth : prompt.dialogWidth - Units.gu(3.2)
    // As wide as ConfirmDialog's and AlertDialog's buttons.
    readonly property real _buttonWidth: Units.gu(26.0)

    // The clear space between Allow and Deny, and between the box and Allow,
    // so the two answers read as two. The Dialog's Column puts 0.5 gu
    // between all its children (ConfirmDialog keeps that); the spacers make
    // up the rest. No other dialog stacks two answers this far apart, and
    // the shell's MessageDialog none, so it is a prompt-only gap. Keep it
    // over twice that spacing: a spacer of no height is skipped by the
    // Column, and the gap falls back to 0.5 gu.
    property real _buttonGap: Units.gu(1.5)

    // LuneOSButton's affirmativeColor and negativeColor (QtQuick.Controls.LuneOS),
    // as LuneOS.Forms' Colors does: the shell's dialogs are not drawn by that
    // style, so the prompt does not load its plugin for two colours.
    readonly property color _allowColor: "#2aa100"
    readonly property color _denyColor: "#be0003"

    // "SHA256:" on a line of its own, then the key's hash in groups of four,
    // four groups a line, so it breaks between groups and is read a group at
    // a time against what the computer shows ("adb" prints it whole).
    function _grouped(f) {
        var head = "";
        if (f.indexOf("SHA256:") === 0) {
            head = "SHA256:\n";
            f = f.substring(7);
        }
        var groups = [];
        for (var i = 0; i < f.length; i += 4)
            groups.push(f.substring(i, i + 4));
        // Four groups a line (a SHA256 key: 4, 4 and 3), not one left alone
        // at the end; a narrow screen still wraps between groups.
        var lines = [];
        for (var j = 0; j < groups.length; j += 4)
            lines.push(groups.slice(j, j + 4).join(" "));
        return head + lines.join("\n");
    }

    // Sized as the shell's own system dialog (LockScreen/MessageDialog):
    // the title "large", the words under it "medium", both scaling with the
    // device. Dialog's fixed 16 px title read as too small beside it.
    title: "Allow USB debugging?"
    titlePixelSize: FontUtils.sizeToPixels("large")
    message: "A computer wants to use USB debugging. Its key fingerprint is:"
    messagePixelSize: FontUtils.sizeToPixels("medium")
    dialogWidth: Math.min(Units.gu(36), parent ? parent.width - Units.gu(2) : Units.gu(36))
    dialogHeight: fittedHeight
    visible: false

    function ask(fingerprint, timeoutMs) {
        if (typeof fingerprint !== "string" || fingerprint === "")
            return;
        _fingerprint = fingerprint;
        alwaysBox.checked = false;
        _armed = false;
        arming.restart();
        if (timeoutMs !== undefined && timeoutMs > 0)
            prompt.timeoutMs = timeoutMs;
        deadline.restart();
        open();
    }

    function withdraw() {
        deadline.stop();
        arming.stop();
        _armed = false;
        _fingerprint = "";
        if (opened)
            close();
    }

    function _answer(allow) {
        if (_fingerprint === "")
            return;
        // Not before the user can have seen which computer this is.
        if (allow && !_armed)
            return;
        var fp = _fingerprint;
        var keep = allow && alwaysBox.checked;
        deadline.stop();
        arming.stop();
        _armed = false;
        _fingerprint = "";
        close();
        answered(fp, allow, keep);
    }

    property Timer _arming: Timer {
        id: arming
        interval: prompt.armDelayMs
        onTriggered: prompt._armed = true
    }

    // Not a child: Dialog's default property takes the Items it lays out.
    property Timer _deadline: Timer {
        id: deadline
        interval: prompt.timeoutMs
        onTriggered: prompt._answer(false)
    }

    Text {
        objectName: "usbDebuggingFingerprint"
        width: prompt._contentWidth
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        // Between the groups; a group is never split.
        wrapMode: Text.WordWrap
        // The host's key, not its words: it cannot bring markup of its own.
        textFormat: Text.PlainText
        text: prompt._grouped(prompt.fingerprint)
        color: "#292929"
        // Monospaced, so the groups line up and l, I and 1 differ. Named:
        // fontconfig's "monospace" is Prelude on LuneOS. An image without
        // Liberation Mono falls back to the default face, still grouped.
        font.family: "Liberation Mono"
        font.pixelSize: FontUtils.sizeToPixels("medium")
    }

    DialogCheckBox {
        id: alwaysBox
        objectName: "usbDebuggingAlways"
        text: "Always allow from this computer"
        // The content's width less the box (2.4 gu) and its 1 gu gap.
        labelWidth: prompt._contentWidth - Units.gu(3.4)
        anchors.horizontalCenter: parent.horizontalCenter
        labelPixelSize: FontUtils.sizeToPixels("medium")
        enabled: prompt.armed
        opacity: enabled ? 1 : 0.4
    }

    Item {
        objectName: "usbDebuggingGapAboveAllow"
        width: 1
        height: Math.max(0, prompt._buttonGap - 2 * parent.spacing)
    }
    // First, as asked of the user. Green, and dimmed and untappable until
    // it is armed: a tap already on its way to where Allow appears lands in
    // the wait and does nothing.
    DialogButton {
        objectName: "usbDebuggingAllow"
        text: "Allow"
        enabled: prompt.armed
        opacity: enabled ? 1 : 0.4
        color: prompt._allowColor
        fontcolor: "white"
        buttonWidth: prompt._buttonWidth
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: prompt._answer(true)
    }
    Item {
        objectName: "usbDebuggingGapAboveDeny"
        width: 1
        height: Math.max(0, prompt._buttonGap - 2 * parent.spacing)
    }
    DialogButton {
        objectName: "usbDebuggingDeny"
        text: "Deny"
        color: prompt._denyColor
        fontcolor: "white"
        buttonWidth: prompt._buttonWidth
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: prompt._answer(false)
    }
}
