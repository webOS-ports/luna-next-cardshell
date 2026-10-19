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
import LuneOS.Service 1.0
import LuneOS.System 1.0
import LunaNext.Common 0.1

/*
 * Where audio is going: headphones in the jack, a Bluetooth headset.
 *
 * audiod decides the routing itself - it follows the jack through PulseAudio
 * and moves the audio onto a Bluetooth headset when one connects - and
 * reports the result in org.webosports.service.audio/getStatus. This only
 * listens, for the status bar icon and the brief alert.
 *
 * "headset" is false both when the jack is empty and when the device cannot
 * tell (headsetState "unknown"): on a device without jack detection nothing
 * is routed to the jack, so there is nothing to show either.
 */
Item {
    id: audioOutputService

    property bool serviceAvailable: false

    property bool headset: false
    property bool headsetMic: false
    property bool bluetoothAudio: false
    property string bluetoothAudioName: ""

    /* Emitted when headphones are plugged or pulled, or a Bluetooth headset
     * starts or stops carrying the audio. kind is "wired" or "bluetooth".
     * Not emitted for the first status after (re)connecting: that is how
     * things already were, not something the user just did. */
    signal outputChanged(string kind, bool connected)

    property bool _hadFirstStatus: false

    LunaService {
        id: lunaService
        name: "com.webos.surfacemanager-cardshell"
    }

    ServiceStatus {
        id: audioStatus
        serviceName: "org.webosports.service.audio"
        clientName: "com.webos.surfacemanager-cardshell"
        onAvailableChanged: audioOutputService.handleServiceStatus()
    }

    function handleServiceStatus() {
        audioOutputService.serviceAvailable = audioStatus.available;

        if (!audioOutputService.serviceAvailable) {
            /* audiod went away: we no longer know where audio goes, and its
             * replacement will send a fresh first status. */
            audioOutputService.headset = false;
            audioOutputService.headsetMic = false;
            audioOutputService.bluetoothAudio = false;
            audioOutputService.bluetoothAudioName = "";
            audioOutputService._hadFirstStatus = false;
            return;
        }

        lunaService.subscribe("luna://org.webosports.service.audio/getStatus",
                              JSON.stringify({"subscribe": true}),
                              handleStatus, handleError);
    }

    function handleStatus(message) {
        var payload = JSON.parse(message.payload);
        /* An audiod without output tracking: keep everything off. */
        if (!payload.hasOwnProperty("headset"))
            return;

        var wasHeadset = audioOutputService.headset;
        var wasBluetooth = audioOutputService.bluetoothAudio;

        audioOutputService.headset = payload.headset === true;
        audioOutputService.headsetMic = payload.headsetMic === true;
        audioOutputService.bluetoothAudio = payload.bluetoothAudio === true;
        audioOutputService.bluetoothAudioName = payload.bluetoothAudioName || "";

        if (!audioOutputService._hadFirstStatus) {
            audioOutputService._hadFirstStatus = true;
            return;
        }

        if (audioOutputService.headset !== wasHeadset)
            audioOutputService.outputChanged("wired", audioOutputService.headset);
        if (audioOutputService.bluetoothAudio !== wasBluetooth)
            audioOutputService.outputChanged("bluetooth", audioOutputService.bluetoothAudio);
    }

    function handleError(message) {
        console.log("AudioOutputService: " + message.payload);
    }
}
