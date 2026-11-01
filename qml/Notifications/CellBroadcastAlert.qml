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
import QtMultimedia 6.3
import LuneOS.Service 1.0
import LunaNext.Common 0.1

import "../Utils"

/*
 * A public warning, over everything including the lock screen, until it is
 * acknowledged. That goes for an incoming call too: ETSI TS 102 900 6.1.3 has
 * the warning stay up, and the call answered once it has been acknowledged.
 *
 * The attention tone plays once: the file already holds the pattern twice over.
 *
 * It plays on palerts, whose volume is its own: the ringtone slider does not
 * turn a warning down, and no system volume has to be raised and put back
 * for it. The master mute does apply, as the ringer mode does on Android for a
 * channel not marked to override it.
 *
 * Never during a call. On MediaTek's HAL whatever reaches the primary sink
 * during a call goes to the modem as background sound, so a call gets no tone
 * at all, not even a quiet one: it starts when the call ends if the warning
 * is still up, and a warning arriving during a call only vibrates. Android
 * plays it quietly instead (IN_CALL_VOLUME, 0.125); that level is kept for
 * headphones, where it also applies.
 */
Item {
    id: root

    /* A call is up: no tone, and the display is left alone for the proximity
     * sensor. */
    property bool inCall: false
    /* Headphones or a Bluetooth headset are carrying the audio. */
    property bool headphones: false

    /* The warnings not acknowledged yet, oldest first. */
    property var pending: []

    /* The tone is due, and whether it may sound now. */
    property bool toneOwed: false
    readonly property bool toneWanted: toneOwed && !inCall

    readonly property string currentText: pending.length > 0 ? pending[0] : ""

    visible: pending.length > 0

    function show(text, soundFile) {
        pending = pending.concat([text]);
        vibrate();
        if (soundFile.length > 0) {
            tone.source = "file://" + soundFile;
            toneOwed = true;
        }
        wakeDisplay();
    }

    function acknowledge() {
        pending = pending.slice(1);
        if (pending.length === 0) {
            toneOwed = false;
            vibrationTimer.stop();
        }
    }

    function callService(uri, payload) {
        service.call(uri, JSON.stringify(payload), undefined, function(message) {
            console.warn("CellBroadcastAlert: " + uri + " failed: " + message);
        });
    }

    /* ETSI TS 102 900 6.1.2 asks for a vibration cadence of its own, so it
     * goes with the tone: long, short, short, half a second apart. */
    readonly property var vibrationCadence: [2000, 1000, 1000]
    property int _vibrationStep: 0

    function vibrate() {
        _vibrationStep = 0;
        _nextVibration();
    }

    function _nextVibration() {
        var duration = vibrationCadence[_vibrationStep++];
        callService("luna://com.palm.vibrate/vibrate", {"period": 500, "duration": duration});
        if (_vibrationStep < vibrationCadence.length) {
            vibrationTimer.interval = duration + 500;
            vibrationTimer.restart();
        }
    }

    function wakeDisplay() {
        if (!inCall)
            callService("luna://com.palm.display/control/setState", {"state": "on"});
    }

    onToneWantedChanged: {
        if (toneWanted) {
            tone.play();
        } else {
            tone.stop();
        }
    }

    onInCallChanged: {
        if (!inCall && visible)
            wakeDisplay();
    }

    Timer {
        id: vibrationTimer
        onTriggered: root._nextVibration()
    }

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
    }

    MediaPlayer {
        id: tone
        objectName: "cellBroadcastTone"
        audioOutput: AudioOutput {
            id: toneOutput
            objectName: "cellBroadcastOutput"
            volume: root.headphones ? 0.125 : 1.0
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                root.toneOwed = false;
        }
        onErrorOccurred: (error, errorString) => {
            console.warn("CellBroadcastAlert: tone failed: " + errorString);
            root.toneOwed = false;
        }
    }

    // As RingManager in the Phone app: the audio policy knows a stream by the
    // sink it plays on. Without that sink (a desktop) the default output stays.
    MediaDevices {
        id: mediaDevices
        onAudioOutputsChanged: root._useAlertSink()
    }

    Component.onCompleted: _useAlertSink()

    function _useAlertSink() {
        var outputs = mediaDevices.audioOutputs;
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].id == "palerts") {
                toneOutput.device = outputs[i];
                return;
            }
        }
    }

    // Nothing behind a warning can be touched until it has been read.
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.8
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Units.gu(2)
        spacing: Units.gu(1)

        Text {
            id: title
            width: content.width
            text: "Emergency Alert"
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("large")
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        // A message can run to fifteen pages.
        Flickable {
            id: messageArea
            width: content.width
            height: content.height - title.height - okButton.height - 2 * content.spacing
            contentHeight: message.height
            clip: true

            Text {
                id: message
                objectName: "cellBroadcastMessage"
                width: messageArea.width
                // Network text, so it is never taken for markup.
                textFormat: Text.PlainText
                text: root.currentText
                color: "white"
                font.pixelSize: FontUtils.sizeToPixels("medium")
                wrapMode: Text.Wrap
            }
        }

        ActionButton {
            id: okButton
            width: content.width
            height: Units.gu(5)
            caption: "OK"
            affirmative: true
            onAction: root.acknowledge()
        }
    }
}
