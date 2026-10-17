/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0
import QtTest 1.2
import "../qml/Connectors"
import "../qml/LunaSysAPI"

/*
 * Volume Down as half of the screenshot chord changes nothing: no volume
 * step, so no click and no indicator in the shot. On its own it still steps
 * the volume once per tap, and ramps when held. Wired as CardsArea wires it.
 */
Item {
    id: root

    QtObject {
        id: fakeDisplay
        property var onReply: null
        function subscribe(uri, args, reply, error) {
            onReply = reply;
            return { cancel: function () {} };
        }
        function reportRelease() {
            if (onReply)
                onReply({ payload: JSON.stringify({ powerKey: "released" }) });
        }
    }

    VolumeControl {
        id: volume
        deferVolumeDown: shot.armed
        volumeDownTaken: shot.volumeDownTaken
        onVolumeKeyPressed: (key) => shot.volumeKey(key, true)
        onVolumeKeyReleased: (key) => shot.volumeKey(key, false)
    }

    ScreenshotKeys {
        id: shot
        displayService: fakeDisplay
    }

    SignalSpy { id: shots; target: shot; signalName: "screenshotRequested" }

    TestCase {
        name: "VolumeControl"

        readonly property int start: 50

        function init() {
            shots.clear();
            shot.displayOn = true;
            volume.currentVolume = start;
        }

        function cleanup() {
            if (shot._powerDown)
                shot._onKey(Qt.Key_PowerOff, false, false, 0);
            if (shot._volumeDown)
                volDownUp();
            fakeDisplay.reportRelease();
            compare(volume._volumeDownPending, false, "a held-back step was left behind");
        }

        // In the order VolumeKeys emits them: the press is reported before the
        // volume is stepped for it.
        function volDownPress() {
            volume._volumeKeys.keyPressed(Qt.Key_VolumeDown);
            volume._volumeKeys.volumeDown();
        }
        function volDownRepeat() { volume._volumeKeys.volumeDown(); }
        function volDownUp() { volume._volumeKeys.keyReleased(Qt.Key_VolumeDown); }
        function power(pressed) { return shot._onKey(Qt.Key_PowerOff, pressed, false, 0); }

        function test_tapStepsOnce() {
            volDownPress();
            compare(volume.currentVolume, start, "stepped before the chord could be ruled out");
            volDownUp();
            compare(volume.currentVolume, start - 10);
        }

        function test_holdRamps() {
            volDownPress();
            volDownRepeat();           // 700 ms in: the held-back step
            compare(volume.currentVolume, start - 10);
            volDownRepeat();
            volDownRepeat();
            compare(volume.currentVolume, start - 30);
            volDownUp();
            compare(volume.currentVolume, start - 30, "the held-back step was taken twice");
        }

        function test_holdVolumeTapPowerChangesNothing() {
            volDownPress();
            power(true);
            wait(100);
            power(false);
            compare(shots.count, 1);
            volDownUp();
            compare(volume.currentVolume, start);
        }

        function test_heldOnAfterTheShotRampsNothing() {
            volDownPress();
            power(true);
            wait(50);
            power(false);
            compare(shots.count, 1);
            volDownRepeat();
            volDownRepeat();
            volDownUp();
            compare(volume.currentVolume, start);
        }

        function test_holdPowerTapVolumeChangesNothing() {
            power(true);
            volDownPress();
            wait(100);
            volDownUp();
            compare(shots.count, 1);
            power(false);
            compare(volume.currentVolume, start);
        }

        function test_noChordStillSteps() {
            // Power tapped for longer than legacy's 500 ms: no shot, so the
            // press was a volume press after all.
            volDownPress();
            power(true);
            wait(650);
            power(false);
            compare(shots.count, 0);
            volDownUp();
            compare(volume.currentVolume, start - 10);
        }

        function test_nextPressStepsAgain() {
            volDownPress();
            power(true); wait(50); power(false);
            volDownUp();
            compare(volume.currentVolume, start);
            volDownPress();
            volDownUp();
            compare(volume.currentVolume, start - 10);
        }

        function test_displayOffStepsOnPress() {
            // Nothing can chord with the display off, so nothing is held back.
            shot.displayOn = false;
            volDownPress();
            compare(volume.currentVolume, start - 10);
            volDownUp();
            compare(volume.currentVolume, start - 10);
        }

        function test_volumeUpUntouched() {
            volume._volumeKeys.keyPressed(Qt.Key_VolumeUp);
            volume._volumeKeys.volumeUp();
            compare(volume.currentVolume, start + 10);
            volume._volumeKeys.keyReleased(Qt.Key_VolumeUp);
            compare(volume.currentVolume, start + 10);
        }
    }
}
