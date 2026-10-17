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
import LunaNext.Common 0.1
import LunaNext.Shell 0.1

Item {
    id: volumeControl

    //! A volume key went down or came up (Qt.Key_VolumeUp/Down). VolumeKeys
    //! takes those keys before any key filter sees them, so this is the only
    //! way to know one is held - for the screenshot chord.
    signal volumeKeyPressed(int key)
    signal volumeKeyReleased(int key)

    /*!
     * Hold Volume Down's step back until the key comes up, so that a press
     * which turns out to be half of the screenshot chord changes nothing - no
     * volume step, no click, no indicator in the screenshot. Legacy's Home key,
     * which Volume Down stands in for, had nothing to undo. Holding the key
     * still ramps the volume: the held-back step is taken when the key starts
     * repeating, 700 ms in. Read at each press.
     */
    property bool deferVolumeDown: false

    /*!
     * True when the Volume Down press under way belongs to a screenshot chord;
     * its held-back step is then dropped instead of taken, and so is every
     * repeat. Read when the key repeats or comes up, after volumeKeyReleased
     * has been handled.
     */
    property bool volumeDownTaken: false

    //! The step of the press now coming from VolumeKeys is to be held back.
    property bool _deferNextVolumeDown: false
    //! A Volume Down step is held back, waiting for the key to come up.
    property bool _volumeDownPending: false

    //! What VolumeKeys reports; tests drive it.
    readonly property alias _volumeKeys: volumeKeys

    VolumeKeys {
        id: volumeKeys
        onVolumeUp: handleVolumeUp()
        onVolumeDown: volumeControl._volumeDownStep()
    }

    // Through Connections rather than handlers on VolumeKeys itself: a
    // luneos-components from before keyPressed/keyReleased does not have them,
    // and the volume keys must keep working there - without these, no step is
    // ever held back.
    //
    // VolumeKeys reports the press before it steps the volume for it, so
    // _deferNextVolumeDown is set in time for that step.
    Connections {
        target: volumeKeys
        ignoreUnknownSignals: true
        function onKeyPressed(key) {
            if (key === Qt.Key_VolumeDown) {
                volumeControl._deferNextVolumeDown = volumeControl.deferVolumeDown;
                volumeControl._volumeDownPending = false;
            }
            volumeControl.volumeKeyPressed(key);
        }
        function onKeyReleased(key) {
            volumeControl.volumeKeyReleased(key);
            if (key === Qt.Key_VolumeDown) {
                volumeControl._deferNextVolumeDown = false;
                volumeControl._flushVolumeDown();
            }
        }
    }

    function _volumeDownStep() {
        // The press's own step: hold it back.
        if (volumeControl._deferNextVolumeDown) {
            volumeControl._deferNextVolumeDown = false;
            volumeControl._volumeDownPending = true;
            return;
        }
        // The first repeat: the key is being held to ramp the volume, so the
        // held-back step is taken now, in this repeat's place. That keeps
        // the indicator moving one step at a time.
        if (volumeControl._volumeDownPending) {
            volumeControl._flushVolumeDown();
            return;
        }
        // A press that took a screenshot ramps nothing, however long it is
        // held after.
        if (!volumeControl.volumeDownTaken)
            handleVolumeDown();
    }

    function _flushVolumeDown() {
        if (!volumeControl._volumeDownPending)
            return;
        volumeControl._volumeDownPending = false;
        if (!volumeControl.volumeDownTaken)
            handleVolumeDown();
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
    readonly property int volumeStep: 10

    Component.onCompleted: {
        audioService.subscribe("luna://com.webos.service.audio/master/getVolume",
                               JSON.stringify({"subscribe": true}),
                               handleVolumeStatus, handleVolumeError);
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

    // soundOutput is required by audiod's schema (REQUIRED_2(soundOutput, volume));
    // sending {} - as the calls to the old service did - is rejected outright.
    function applyVolume(volume) {
        if (volume < 0) volume = 0;
        if (volume > 100) volume = 100;
        volumeControl.currentVolume = volume;
        audioService.call("luna://com.webos.service.audio/master/setVolume",
                          JSON.stringify({"soundOutput": volumeControl.soundOutput,
                                          "volume": volume}), null, null);
    }

    function handleVolumeUp() {
        applyVolume(volumeControl.currentVolume + volumeControl.volumeStep);
    }

    function handleVolumeDown() {
        applyVolume(volumeControl.currentVolume - volumeControl.volumeStep);
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
