/*
 * Copyright (C) 2026 alan-morford <alan-morford@users.noreply.github.com>
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
import WebOSCoreCompositor 1.0

/*!
 * Volume down and power pressed together take a screenshot, the way phones
 * do it now.
 *
 * The two keys arrive by different routes. Power reaches the compositor's key
 * filter (Qt.Key_PowerOff). Volume down never does: LunaNext.Shell's VolumeKeys
 * takes the volume keys in an application-wide event filter that runs first,
 * so VolumeControl hands each volume-down step to stepVolumeDown() here
 * instead of acting on it. "Together" is then a time window between the two
 * presses, in either order, which is how Android detects the same chord.
 *
 * Neither key may do its own job when it is part of a chord:
 *
 *  - Volume down. A press with power already down is the chord and steps
 *    nothing. A press on its own is held back for chordWindowMs, and only
 *    steps the volume if power has not come in the meantime - so a chord
 *    never shows the volume indicator or plays its sound. That is the delay
 *    every first volume-down step pays while the display is on; auto-repeats
 *    are not held back.
 *
 *  - Power. LunaDisplayManager reads it itself and toggles the display on its
 *    release. A chord holds a powerKeyBlock (com.palm.display/control/
 *    setProperty), which makes it drop that release; the block is a call kept
 *    open, and ends when it is cancelled a little after power comes back up.
 *
 * Only while the display is on: with it off, power is the way to wake the
 * screen, and volume down is not held back.
 */
Item {
    id: screenshotChord

    //! LunaSysAPI's VolumeControl. Its volume-down steps come here while this
    //! is in place, and go back to it through volumeControl.stepVolumeDown().
    property var volumeControl: null

    //! How far apart the two presses may be and still count as together.
    property int chordWindowMs: 200

    signal triggered()

    readonly property int resultNextPolicy: 2   //!< see HardwareKeys

    //! VolumeKeys repeats a held key every 80 ms after 700 ms; anything closer
    //! than this to the previous step is one of those, not a new press.
    readonly property int _repeatGapMs: 400

    property bool displayOn: true

    property bool _installed: false
    property bool _powerHeld: false
    property bool _firedThisPower: false
    property bool _suppressRepeats: false
    property real _powerDownAt: 0
    property real _lastVolumeStepAt: 0
    property var _powerKeyBlock: null

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            screenshotChord._install();
            service.subscribe("luna://com.palm.display/control/status",
                              JSON.stringify({"subscribe": true}),
                              screenshotChord._handleDisplayStatus,
                              function (error) {
                                  console.warn("ScreenshotChord: display status subscription failed: " + JSON.stringify(error));
                              });
        }
    }

    KeyFilter { id: chordKeyFilter }

    Timer {
        id: heldVolumeStepTimer
        // The volume-down press waiting to find out whether power follows.
        interval: screenshotChord.chordWindowMs
        onTriggered: screenshotChord._stepVolume()
    }

    Timer {
        id: releaseBlockTimer
        // Long enough for LunaDisplayManager to have handled the power release
        // it read itself before the block goes away.
        interval: 500
        onTriggered: screenshotChord._releasePowerKeyBlock()
    }

    Component.onCompleted: {
        if (screenshotChord.volumeControl)
            screenshotChord.volumeControl.volumeDownHandler = screenshotChord.volumeDown;
    }

    onVolumeControlChanged: {
        if (screenshotChord.volumeControl)
            screenshotChord.volumeControl.volumeDownHandler = screenshotChord.volumeDown;
    }

    function _install() {
        if (screenshotChord._installed)
            return;

        if (!compositor) {
            console.warn("ScreenshotChord: no compositor, the screenshot chord is off");
            return;
        }

        // Share whichever filter is installed, as HardwareKeys does.
        if (!compositor.keyFilter)
            compositor.keyFilter = chordKeyFilter;

        compositor.keyFilter.addKeyFilter(screenshotChord._onKey, "screenshotChord");
        screenshotChord._installed = true;
    }

    // Watches power and never consumes it: everything else that wants the key
    // still gets it.
    function _onKey(keycode, pressed, autoRepeat, nativeModifiers) {
        if (keycode !== Qt.Key_PowerOff || autoRepeat)
            return screenshotChord.resultNextPolicy;

        if (pressed) {
            screenshotChord._powerHeld = true;
            screenshotChord._powerDownAt = Date.now();
            screenshotChord._firedThisPower = false;
            // Volume down came first and is still waiting: this is the chord.
            if (heldVolumeStepTimer.running) {
                heldVolumeStepTimer.stop();
                screenshotChord._fire();
            }
        } else {
            screenshotChord._powerHeld = false;
            if (screenshotChord._powerKeyBlock)
                releaseBlockTimer.restart();
        }

        return screenshotChord.resultNextPolicy;
    }

    //! Every volume-down step VolumeKeys makes: the press and its auto-repeats.
    function volumeDown() {
        var now = Date.now();
        var repeat = now - screenshotChord._lastVolumeStepAt < screenshotChord._repeatGapMs;
        screenshotChord._lastVolumeStepAt = now;

        if (repeat) {
            // A volume-down held on after its chord steps nothing until let go.
            if (screenshotChord._suppressRepeats || heldVolumeStepTimer.running)
                return;
            screenshotChord._stepVolume();
            return;
        }
        screenshotChord._suppressRepeats = false;

        if (!screenshotChord.displayOn) {
            screenshotChord._stepVolume();
            return;
        }

        // Power is already down: this is the chord, and steps nothing.
        if (screenshotChord._powerHeld && !screenshotChord._firedThisPower) {
            screenshotChord._suppressRepeats = true;
            screenshotChord._fire();
            return;
        }

        heldVolumeStepTimer.restart();
    }

    function _stepVolume() {
        if (screenshotChord.volumeControl)
            screenshotChord.volumeControl.stepVolumeDown();
    }

    function _fire() {
        if (screenshotChord._firedThisPower || !screenshotChord.displayOn)
            return;

        screenshotChord._firedThisPower = true;
        screenshotChord._suppressRepeats = true;

        if (!screenshotChord._powerKeyBlock) {
            screenshotChord._powerKeyBlock = service.subscribe(
                        "luna://com.palm.display/control/setProperty",
                        JSON.stringify({"client": "screenshot-chord", "powerKeyBlock": true}),
                        function (message) { },
                        function (error) {
                            console.warn("ScreenshotChord: could not block the power key: " + JSON.stringify(error));
                        });
        }
        releaseBlockTimer.stop();

        screenshotChord.triggered();
    }

    function _releasePowerKeyBlock() {
        if (!screenshotChord._powerKeyBlock)
            return;
        screenshotChord._powerKeyBlock.cancel();
        screenshotChord._powerKeyBlock = null;
    }

    // As NotificationLed reads it: "state" in the first reply, "event" after.
    function _handleDisplayStatus(message) {
        var response = JSON.parse(message.payload);
        if (response.state !== undefined)
            screenshotChord.displayOn = (response.state !== "off");
        else if (response.event === "displayOff")
            screenshotChord.displayOn = false;
        else if (response.event === "displayOn" || response.event === "displayDimmed")
            screenshotChord.displayOn = true;
    }

    Component.onDestruction: {
        if (screenshotChord.volumeControl &&
                screenshotChord.volumeControl.volumeDownHandler === screenshotChord.volumeDown)
            screenshotChord.volumeControl.volumeDownHandler = null;
        screenshotChord._releasePowerKeyBlock();
    }
}
