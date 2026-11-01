/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LuneOS.Service 1.0
import LuneOS.System 1.0
import LunaNext.Common 0.1

import "../Connectors"
import "../Utils"

Item {
    id: root

    visible: false

    anchors.centerIn: parent
    width: image.width + Units.gu(1)
    height: image.height

    property bool _hadFirstAudioStatus: false

    /* The output the last status was about, to tell a routing change from
     * a volume change. */
    property string _lastSoundOutput: ""

    /* Emitted each time the alert comes up, for CentreAlertSlot. */
    signal shown()

    /* Takes the alert down before its time, when another one takes the
     * centre of the screen. */
    function dismiss() {
        hideTimer.stop();
        root.visible = false;
    }

    // Was a hand-rolled playFeedback call of its own, which meant the volume
    // click was the one feedback sound Settings' "System Sounds" switch did
    // not silence.
    FeedbackSound { id: adjustVolumeSound; soundName: "AdjustVolume" }

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        running: false
        onTriggered: root.visible = false
    }

    Rectangle {
        id: imageBackground

        anchors.centerIn: parent
        anchors.fill: parent
        color: "black"
        opacity: 0.4
        radius: 4
    }

    Image {
        id:  image
        verticalAlignment: Image.AlignBottom;
        anchors.centerIn: parent
        opacity: 1.0
    }

    ServiceStatus {
        id: audioServiceStatus
        serviceName: "com.webos.service.audio"
        clientName: "com.webos.surfacemanager-cardshell"

        onAvailableChanged: available ? connected() : disconnected()

        // The bus can report "connected" more than once without a
        // "disconnected" in between (audiod registering its bus name while it
        // is still starting). "available" only changes on a real change, so
        // this subscribes once: a second subscription played the volume click
        // twice, a few tens of milliseconds apart.
        function connected() {
            audioService.subscribe("luna://com.webos.service.audio/master/getVolume",
                                   "{\"subscribe\":true}",
                                   onAudioStatusChanged, onError);
        }

        function disconnected() {
            console.log("Lost audio service!");
        }
    }

    LunaService {
        id: audioService

        name: "com.webos.surfacemanager-cardshell"
    }

    function onAudioStatusChanged(message) {
        var payload = JSON.parse(message.payload);
        // audiod nests the fields under volumeStatus, where the old
        // audio-service had them at the top level. Accept either.
        var response = payload.hasOwnProperty("volumeStatus") ? payload.volumeStatus : payload;

        var previousOutput = _lastSoundOutput;
        if (response.hasOwnProperty("soundOutput"))
            _lastSoundOutput = response.soundOutput;

        if (!_hadFirstAudioStatus) {
            _hadFirstAudioStatus = true;
            return;
        }

        /*
         * A status that comes from the audio moving somewhere else is not
         * the user changing the volume, and shows nothing. LunaSysMgr's
         * NativeAlertManager::cbAudioControlsChanged() gated the volume alert
         * the same way: a change that came with a "scenario" change (a
         * headset plugged in, Bluetooth taking over) never reached
         * actOnChanged(). Without that, the volume level came up on top of
         * the headphones AudioOutputAlert shows for the same plug.
         *
         * audiod's equivalents: it restores the stored volume of an output
         * that connects and reports that with callerId "internal"
         * (OSEMasterVolumeManager::DBSetVoulumeCallbackPA), and a status
         * naming another output than the last one is the route changing.
         */
        if (isRoutingChange(payload, response, previousOutput))
            return;

        adjustVolumeSound.play();

        // we don't indicate volume changes when sound is muted
        if (response.muted) {
            image.source = "../images/bell_off.png"
            image.width = Units.gu(9.6)
            image.height = Units.gu(9.6)
        }
        else {
            var normalizedVolume = 0;
            if (response.volume > 0)
                normalizedVolume = ((Math.round(response.volume/11))*10);
            if (normalizedVolume < 0)
                normalizedVolume = 0;
            image.source = ("../images/notification-music-indicator-" + normalizedVolume + ".png");
            image.width = Units.gu(24)
            image.height = Units.gu(7.2)
        }

        root.visible = true;
        hideTimer.restart();
        root.shown();
    }

    function isRoutingChange(payload, response, previousOutput) {
        if (payload.callerId === "internal")
            return true;
        return previousOutput !== "" && response.hasOwnProperty("soundOutput") &&
               response.soundOutput !== previousOutput;
    }

    function onError(message) {
        console.log("Failed to call audio service: " + message);
    }
}
