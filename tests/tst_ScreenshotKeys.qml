/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0
import QtTest 1.2
import "../qml/Connectors"

/*
 * Power + Volume Down against legacy's Home + Power timing: hold one, tap the
 * other for at most 500 ms, shot on the tapped key's release, both releases
 * swallowed; and the display manager's power key block held exactly as long
 * as the chord can need it.
 */
Item {
    id: root

    // What ScreenshotKeys asks the display manager for: a subscription that
    // can be cancelled, and that reports the power key's release when blocked.
    QtObject {
        id: fakeDisplay
        property int blocks: 0          // subscriptions made
        property int cancels: 0
        property var onReply: null
        function subscribe(uri, args, reply, error) {
            blocks++;
            onReply = reply;
            return { cancel: function () { fakeDisplay.cancels++; } };
        }
        function reportRelease() {
            if (onReply)
                onReply({ payload: JSON.stringify({ powerKey: "released" }) });
        }
        function active() {
            return blocks - cancels;
        }
    }

    QtObject {
        id: fakeCompositor
        property var installed: []
        property var filters: []
        property QtObject keyFilter: QtObject {
            function addKeyFilter(filter, name) {
                fakeCompositor.installed = fakeCompositor.installed.concat([name]);
                fakeCompositor.filters = fakeCompositor.filters.concat([filter]);
            }
        }
    }

    ScreenshotKeys {
        id: keys
        displayService: fakeDisplay
    }

    SignalSpy { id: shots; target: keys; signalName: "screenshotRequested" }

    TestCase {
        name: "ScreenshotKeys"

        readonly property int accepted: 1
        readonly property int next: 2

        function init() {
            shots.clear();
            fakeDisplay.blocks = 0;
            fakeDisplay.cancels = 0;
            keys.displayOn = true;
        }

        function cleanup() {
            // Let go of anything a test left down, and of a pending block.
            if (keys._powerDown)
                keys._onKey(Qt.Key_PowerOff, false, false, 0);
            if (keys._volumeDown)
                keys._onKey(Qt.Key_VolumeDown, false, false, 0);
            fakeDisplay.reportRelease();
            compare(fakeDisplay.active(), 0, "power key block left held");
        }

        function press(key) { return keys._onKey(key, true, false, 0); }
        function release(key) { return keys._onKey(key, false, false, 0); }

        // In the shell: the chord's filter joins the compositor's key filter.
        function test_installsIntoTheCompositorsFilter() {
            keys._installed = false;
            keys.compositorInstance = fakeCompositor;
            keys._install();
            compare(fakeCompositor.installed, ["screenshotKeys"]);
            // Hands its keys to the same function the tests call.
            compare(fakeCompositor.filters[0](Qt.Key_A, true, false, 0), next);
        }

        function test_legacyWindow() {
            compare(keys.tapWindowMs, 500);
        }

        function test_holdVolumeTapPower() {
            compare(press(Qt.Key_VolumeDown), next);
            compare(fakeDisplay.active(), 1);
            compare(press(Qt.Key_PowerOff), next);
            wait(100);
            compare(release(Qt.Key_PowerOff), accepted);
            compare(shots.count, 1);
            // Still held, and the display manager has not reported yet.
            compare(fakeDisplay.active(), 1);
            compare(release(Qt.Key_VolumeDown), accepted);
            compare(fakeDisplay.active(), 1);
            fakeDisplay.reportRelease();
            compare(fakeDisplay.active(), 0);
        }

        function test_holdPowerTapVolume() {
            press(Qt.Key_PowerOff);
            press(Qt.Key_VolumeDown);
            compare(fakeDisplay.active(), 1);
            wait(100);
            compare(release(Qt.Key_VolumeDown), accepted);
            compare(shots.count, 1);
            compare(release(Qt.Key_PowerOff), accepted);
            fakeDisplay.reportRelease();
            compare(fakeDisplay.active(), 0);
        }

        function test_tapLongerThan500msIsNoChord() {
            press(Qt.Key_VolumeDown);
            press(Qt.Key_PowerOff);
            wait(650);   // legacy: 500 ms
            compare(release(Qt.Key_PowerOff), next);
            compare(release(Qt.Key_VolumeDown), next);
            compare(shots.count, 0);
        }

        function test_holdPowerSlowVolumeIsNoChord() {
            press(Qt.Key_PowerOff);
            press(Qt.Key_VolumeDown);
            wait(650);   // legacy: 500 ms
            compare(release(Qt.Key_VolumeDown), next);
            compare(release(Qt.Key_PowerOff), next);
            compare(shots.count, 0);
        }

        function test_heldKeyStartTimeDoesNotMatter() {
            // The held key may have been down for long; only the tap counts.
            press(Qt.Key_VolumeDown);
            wait(650);   // legacy: 500 ms
            press(Qt.Key_PowerOff);
            wait(50);
            release(Qt.Key_PowerOff);
            compare(shots.count, 1);
        }

        function test_keysOnTheirOwn() {
            compare(press(Qt.Key_PowerOff), next);
            compare(release(Qt.Key_PowerOff), next);
            compare(fakeDisplay.blocks, 0, "power alone must not block power");
            compare(press(Qt.Key_VolumeDown), next);
            compare(release(Qt.Key_VolumeDown), next);
            compare(fakeDisplay.active(), 0);
            compare(shots.count, 0);
        }

        function test_otherKeysUntouched() {
            compare(keys._onKey(Qt.Key_VolumeUp, true, false, 0), next);
            compare(keys._onKey(Qt.Key_A, true, false, 0), next);
            compare(fakeDisplay.blocks, 0);
        }

        function test_autoRepeatIsTheSamePress() {
            press(Qt.Key_VolumeDown);
            press(Qt.Key_PowerOff);
            wait(300);
            // A repeat of the held power key would restart its clock in legacy's
            // way of counting; it is the same press.
            keys._onKey(Qt.Key_PowerOff, true, true, 0);
            wait(300);
            release(Qt.Key_PowerOff);
            compare(shots.count, 0);
        }

        function test_displayOffArmsNothing() {
            keys.displayOn = false;
            press(Qt.Key_VolumeDown);
            press(Qt.Key_PowerOff);
            wait(50);
            compare(release(Qt.Key_PowerOff), next);
            compare(fakeDisplay.blocks, 0);
            compare(shots.count, 0);
        }

        function test_blockLetGoWithoutReply() {
            // The display manager never reports the release: fall back after 1 s.
            press(Qt.Key_VolumeDown);
            press(Qt.Key_PowerOff);
            release(Qt.Key_PowerOff);
            release(Qt.Key_VolumeDown);
            compare(fakeDisplay.active(), 1);
            tryCompare(fakeDisplay, "cancels", 1, 2000);
        }

        // As on a device: Volume Down from VolumeKeys, power from the filter.
        function test_volumeFromVolumeKeys() {
            keys.volumeKey(Qt.Key_VolumeDown, true);
            compare(fakeDisplay.active(), 1);
            press(Qt.Key_PowerOff);
            wait(100);
            compare(release(Qt.Key_PowerOff), accepted);
            keys.volumeKey(Qt.Key_VolumeDown, false);
            compare(shots.count, 1);
            fakeDisplay.reportRelease();
            compare(fakeDisplay.active(), 0);
        }

        function test_volumeUpIsNotPartOfIt() {
            keys.volumeKey(Qt.Key_VolumeUp, true);
            press(Qt.Key_PowerOff);
            wait(100);
            compare(release(Qt.Key_PowerOff), next);
            keys.volumeKey(Qt.Key_VolumeUp, false);
            compare(shots.count, 0);
            compare(fakeDisplay.blocks, 0);
        }

        function test_twoShotsInARow() {
            press(Qt.Key_VolumeDown);
            press(Qt.Key_PowerOff); wait(50); release(Qt.Key_PowerOff);
            press(Qt.Key_PowerOff); wait(50); release(Qt.Key_PowerOff);
            compare(shots.count, 2);
        }
    }
}
