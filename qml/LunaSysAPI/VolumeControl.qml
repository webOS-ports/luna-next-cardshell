/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
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
import LunaNext.Shell 0.1

import "VolumeKeyRequest.js" as VolumeKeyRequest

Item {
    id: volumeControl

    VolumeKeys {
        onVolumeUp: handleVolumeUp()
        onVolumeDown: handleVolumeDown()
    }

    // Volume state, tracked from audiod so the keys can step it themselves.
    //
    // These used to call org.webosports.service.audio, the audio-service LuneOS
    // no longer ships. audiod claims the bus name, so the calls arrived but found
    // no such method and the keys did nothing at all.
    //
    // audiod's own master/volumeUp moves the volume by exactly 1
    // (volume = displayVol+1 in OSEMasterVolumeManager), while the on-screen
    // indicator quantises to tens - Math.round(volume/11)*10 picks one of eleven
    // notification-music-indicator-N images. One press would move the bar by a
    // tenth of a step, so set the volume directly in steps of 10 instead, which
    // is what the old service did.
    property string soundOutput: "pcm_output"
    property int currentVolume: 50
    readonly property int volumeStep: VolumeKeyRequest.step

    //! A call is up: the keys move its volume (see VolumeKeyRequest.js).
    property bool inCall: false

    Component.onCompleted: {
        audioService.subscribe("luna://com.webos.service.audio/master/getVolume",
                               JSON.stringify({"subscribe": true}),
                               handleVolumeStatus, handleVolumeError);
    }

    // Subscribed again whenever audiod comes back, so a restarted audiod
    // does not leave the keys on the master volume during a call.
    ServiceStatus {
        id: phoneStatusService
        serviceName: "com.palm.audio"
        clientName: "com.webos.surfacemanager-cardshell"

        onAvailableChanged: {
            if (available) {
                audioService.subscribe("luna://com.palm.audio/phone/status",
                                       JSON.stringify({"subscribe": true}),
                                       volumeControl.handlePhoneStatus,
                                       volumeControl.handlePhoneError);
            } else {
                volumeControl.inCall = false;
            }
        }
    }

    function handlePhoneStatus(message) {
        volumeControl.inCall = VolumeKeyRequest.inCallOf(JSON.parse(message.payload));
    }

    function handlePhoneError(message) {
        console.log("VolumeControl: cannot follow the call: " + message.payload);
        volumeControl.inCall = false;
    }

    function handleVolumeStatus(message) {
        var payload = JSON.parse(message.payload);
        // audiod nests these under volumeStatus; accept a flat payload too.
        var status = payload.hasOwnProperty("volumeStatus") ? payload.volumeStatus : payload;
        if (status.hasOwnProperty("volume"))
            volumeControl.currentVolume = status.volume;
        if (status.hasOwnProperty("soundOutput") && status.soundOutput.length > 0)
            volumeControl.soundOutput = status.soundOutput;
    }

    function handleVolumeError(message) {
        console.log("VolumeControl: cannot track the volume: " + message.payload);
    }

    function handleKey(up) {
        var request = VolumeKeyRequest.forKey(up, volumeControl.inCall,
                                              volumeControl.soundOutput,
                                              volumeControl.currentVolume);
        if (request.volume >= 0)
            volumeControl.currentVolume = request.volume;
        audioService.call(request.uri, JSON.stringify(request.payload), null, null);
    }

    function handleVolumeUp() {
        handleKey(true);
    }

    function handleVolumeDown() {
        handleKey(false);
    }

    function setMute(mute) {
        audioService.call("luna://com.webos.service.audio/master/muteVolume",
                          JSON.stringify({"soundOutput": volumeControl.soundOutput,
                                          "mute": mute}), null, null);
    }

    LunaService {
        id: audioService
        name: "com.webos.surfacemanager-cardshell"
    }
}
