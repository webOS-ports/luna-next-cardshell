import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"
import "../qml/LunaSysAPI"

/*
 * Volume down + power take a screenshot (ScreenshotChord), and neither key
 * does its own job when it is part of one: volume down steps nothing, and the
 * power key is blocked so the display stays on.
 *
 * The keys are fed the way the shell gets them. Power goes to _onKey(), the
 * function ScreenshotChord registers with the compositor's key filter. Volume
 * down goes through a VolumeControl: volumeKeyPressed/Released are the edges a
 * luneos-components VolumeKeys with keyPressed/keyReleased reports, and
 * handleVolumeDown() is each step it makes. The "legacy" rows leave the edges
 * out, as an older VolumeKeys does, which still runs on some images.
 *
 * Timing is real time: the windows are a few hundred milliseconds, and the
 * waits keep well clear of their edges.
 */
TestCase {
    name: "ScreenshotChord"
    when: windowShown

    property int blocks: 0
    property int unblocks: 0

    VolumeControl { id: control }

    Component {
        id: chordComponent
        ScreenshotChord {
            // No luna-bus here: count the power-key block instead.
            function _blockPowerKey() {
                blocks++;
                return { cancel: function () { unblocks++; } };
            }
        }
    }

    SignalSpy { id: shots; signalName: "triggered" }

    // Stands in for LunaGestureArea.
    QtObject {
        id: gestureArea
        signal swipeRightGesture(int modifiers)
    }

    property var chord: null

    function init() {
        control.inCall = false;
        control.currentVolume = 60;
        blocks = 0;
        unblocks = 0;
        chord = createTemporaryObject(chordComponent, null, { volumeControl: control });
        shots.target = chord;
        shots.clear();
    }

    function cleanup() {
        compare(control.volumeDownHandler === null, false, "still hooked while the test ran");
    }

    function volumeDownPress(edges) {
        if (edges)
            control.volumeKeyPressed(Qt.Key_VolumeDown);
        control.handleVolumeDown();
    }

    function volumeDownRelease(edges) {
        if (edges)
            control.volumeKeyReleased(Qt.Key_VolumeDown);
    }

    function powerPress() { return chord._onKey(Qt.Key_PowerOff, true, false, 0); }
    function powerRelease() { return chord._onKey(Qt.Key_PowerOff, false, false, 0); }

    function modes() {
        return [ { tag: "edges", edges: true }, { tag: "legacy", edges: false } ];
    }

    function test_hooksVolumeDown() {
        verify(control.volumeDownHandler === chord.volumeDown);
        chord.destroy();
        wait(0);
        verify(control.volumeDownHandler === null, "unhooked when it goes away");
        control.volumeDownHandler = null;
        chord = createTemporaryObject(chordComponent, null, { volumeControl: control });
    }

    function test_powerIsNeverConsumed() {
        compare(powerPress(), chord.resultNextPolicy);
        compare(powerRelease(), chord.resultNextPolicy);
        compare(chord._onKey(Qt.Key_VolumeDown, true, false, 0), chord.resultNextPolicy);
    }

    function test_volumeDownThenPowerQuickly_data() { return modes(); }
    function test_volumeDownThenPowerQuickly(data) {
        volumeDownPress(data.edges);
        wait(60);
        powerPress();
        compare(shots.count, 1);
        compare(control.currentVolume, 60, "the chord's volume down steps nothing");
        compare(blocks, 1, "power is blocked so the display stays on");
        wait(300);
        compare(control.currentVolume, 60, "and nothing steps later either");
        volumeDownRelease(data.edges);
        powerRelease();
        compare(unblocks, 0, "the block outlasts power's release a little");
        tryCompare(this, "unblocks", 1, 1500);
    }

    function test_powerThenVolumeDown_data() { return modes(); }
    function test_powerThenVolumeDown(data) {
        powerPress();
        wait(data.edges ? 900 : 100);
        volumeDownPress(data.edges);
        compare(shots.count, 1);
        compare(control.currentVolume, 60);
        compare(blocks, 1);
        volumeDownRelease(data.edges);
        powerRelease();
        tryCompare(this, "unblocks", 1, 1500);
    }

    // The slack asked for on the PR: volume down held, power a bit later than
    // the 200 ms the volume step waits.
    function test_volumeDownHeldThenPowerLater_data() {
        return [ { tag: "edges", edges: true, shot: 1 },
                 { tag: "legacy", edges: false, shot: 0 } ];
    }
    function test_volumeDownHeldThenPowerLater(data) {
        volumeDownPress(data.edges);
        wait(380);
        compare(control.currentVolume, 50, "it stepped after waiting for power");
        powerPress();
        compare(shots.count, data.shot);
        compare(blocks, data.shot);
        volumeDownRelease(data.edges);
        powerRelease();
    }

    function test_volumeDownHeldTooLongBeforePower() {
        volumeDownPress(true);
        wait(700);  // past pairWindowMs (500), before auto-repeat
        powerPress();
        compare(shots.count, 0, "lowering the volume, then turning the screen off");
        compare(blocks, 0);
        volumeDownRelease(true);
        powerRelease();
    }

    function test_volumeDownTapThenPower_data() {
        // Without edges a tap cannot be told from a hold.
        return [ { tag: "edges", edges: true, shot: 0 },
                 { tag: "legacy", edges: false, shot: 1 } ];
    }
    function test_volumeDownTapThenPower(data) {
        volumeDownPress(data.edges);
        wait(40);
        volumeDownRelease(data.edges);
        wait(60);
        powerPress();
        compare(shots.count, data.shot);
        powerRelease();
    }

    function test_volumeDownAloneStepsOnce_data() { return modes(); }
    function test_volumeDownAloneStepsOnce(data) {
        volumeDownPress(data.edges);
        wait(50);
        volumeDownRelease(data.edges);
        if (data.edges)
            compare(control.currentVolume, 50, "a tap let go steps at once");
        tryCompare(control, "currentVolume", 50, 1000);
        wait(400);
        compare(control.currentVolume, 50, "exactly one step");
        compare(shots.count, 0);
    }

    function test_heldVolumeDownRepeats_data() { return modes(); }
    function test_heldVolumeDownRepeats(data) {
        volumeDownPress(data.edges);
        wait(300);
        compare(control.currentVolume, 50);
        // VolumeKeys' auto-repeat: every 80 ms after 700 ms.
        wait(400);
        for (var i = 0; i < 3; ++i) {
            control.handleVolumeDown();
            wait(80);
        }
        compare(control.currentVolume, 20, "repeats are not held back");
        volumeDownRelease(data.edges);
    }

    function test_repeatsAfterTheChordStepNothing_data() { return modes(); }
    function test_repeatsAfterTheChordStepNothing(data) {
        powerPress();
        volumeDownPress(data.edges);
        compare(shots.count, 1);
        wait(700);
        for (var i = 0; i < 3; ++i) {
            control.handleVolumeDown();
            wait(80);
        }
        compare(control.currentVolume, 60);
        volumeDownRelease(data.edges);
        powerRelease();
        // Without edges, a press this soon after the last repeat would be
        // taken for one more (_repeatGapMs).
        wait(data.edges ? 100 : chord._repeatGapMs + 100);
        volumeDownPress(data.edges);
        volumeDownRelease(data.edges);
        tryCompare(control, "currentVolume", 50, 1000, "the next press steps again");
    }

    function test_oneShotPerPowerPress() {
        powerPress();
        volumeDownPress(true);
        volumeDownRelease(true);
        wait(450);
        volumeDownPress(true);
        compare(shots.count, 1);
        volumeDownRelease(true);
        powerRelease();
    }

    function test_powerAloneIsLeftAlone() {
        powerPress();
        wait(100);
        powerRelease();
        wait(700);
        compare(shots.count, 0);
        compare(blocks, 0, "power still turns the display off");
    }

    function test_displayOff_data() { return modes(); }
    function test_displayOff(data) {
        chord._handleDisplayStatus({ payload: JSON.stringify({ event: "displayOff" }) });
        verify(!chord.displayOn);
        volumeDownPress(data.edges);
        compare(control.currentVolume, 50, "not held back with the display off");
        powerPress();
        compare(shots.count, 0, "power wakes the display");
        compare(blocks, 0);
        volumeDownRelease(data.edges);
        powerRelease();

        chord._handleDisplayStatus({ payload: JSON.stringify({ event: "displayOn" }) });
        verify(chord.displayOn);
        chord._handleDisplayStatus({ payload: JSON.stringify({ state: "off" }) });
        verify(!chord.displayOn);
        chord._handleDisplayStatus({ payload: JSON.stringify({ state: "dimmed" }) });
        verify(chord.displayOn);
    }

    function test_volumeUpIsNotPartOfIt() {
        control.volumeKeyPressed(Qt.Key_VolumeUp);
        control.handleVolumeUp();
        compare(control.currentVolume, 70, "volume up is never held back");
        powerPress();
        compare(shots.count, 0);
        control.volumeKeyReleased(Qt.Key_VolumeUp);
        powerRelease();
    }

    // The VM and a Raspberry Pi have neither button: a right swipe is the
    // screenshot there, and only there.
    function test_rightSwipe_data() {
        return [ { tag: "both buttons", buttons: true, shot: 0 },
                 { tag: "a button missing", buttons: false, shot: 1 } ];
    }
    function test_rightSwipe(data) {
        var c = createTemporaryObject(chordComponent, null,
                                      { volumeControl: control, gestureArea: gestureArea,
                                        hasChordButtons: data.buttons });
        shots.target = c;
        shots.clear();
        gestureArea.swipeRightGesture(0);
        compare(shots.count, data.shot);
    }

    function test_buttonsFromSettings() {
        verify(chord.hasChordButtons, "a phone has both, as luna.conf defaults");
    }

    function test_noVolumeControl() {
        var lone = createTemporaryObject(chordComponent, null, {});
        lone.volumeDown();
        lone._onKey(Qt.Key_PowerOff, true, false, 0);
        lone._onKey(Qt.Key_PowerOff, false, false, 0);
        wait(300);
    }
}
