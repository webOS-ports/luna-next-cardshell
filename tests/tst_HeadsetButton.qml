import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors/HeadsetButton.js" as HeadsetButton

/*
 * The headset button's press counting, with a clock of its own: nothing here
 * waits. Each step returns { action, timerMs }; a test runs the "timer" by
 * calling timeout() at the time it would have fired.
 */
TestCase {
    name: "HeadsetButton"

    readonly property int multi: HeadsetButton.multiPressMs
    readonly property int hold: HeadsetButton.holdMs

    //! Presses and releases at the given times (ms) and runs any timer to its end.
    function click(state, at) {
        const down = HeadsetButton.press(state, at);
        compare(down.action, "");
        compare(down.timerMs, hold);
        return HeadsetButton.release(state, at + 80);
    }

    function test_onePressIsPlayPauseOnceThePressesStop() {
        const s = HeadsetButton.initial();
        const up = click(s, 0);
        compare(up.action, "", "a single press waits for a second one");
        compare(up.timerMs, multi);

        const early = HeadsetButton.timeout(s, 80 + multi - 1);
        compare(early.action, "");
        compare(early.timerMs, 1);

        compare(HeadsetButton.timeout(s, 80 + multi).action, "playPause");
        compare(HeadsetButton.timeout(s, 80 + multi + 1000).action, "", "and only once");
    }

    function test_twoPressesAreNextAndNotPlayPause() {
        const s = HeadsetButton.initial();
        click(s, 0);
        const second = click(s, 200);
        compare(second.action, "");
        compare(second.timerMs, multi);
        compare(HeadsetButton.timeout(s, 280 + multi).action, "next");
    }

    function test_threePressesArePreviousAtOnce() {
        const s = HeadsetButton.initial();
        click(s, 0);
        click(s, 200);
        const third = click(s, 400);
        compare(third.action, "previous");
        compare(third.timerMs, 0);
        compare(HeadsetButton.timeout(s, 480 + multi).action, "", "nothing left to count");
    }

    function test_aSlowSecondPressIsItsOwnSinglePress() {
        const s = HeadsetButton.initial();
        click(s, 0);
        compare(HeadsetButton.timeout(s, 80 + multi).action, "playPause");
        click(s, 80 + multi + 500);
        compare(HeadsetButton.timeout(s, 80 + multi + 580 + multi).action, "playPause");
    }

    function test_holdingIsAHoldAndNothingElse() {
        const s = HeadsetButton.initial();
        HeadsetButton.press(s, 0);
        compare(HeadsetButton.timeout(s, hold - 1).action, "", "not held long enough yet");
        compare(HeadsetButton.timeout(s, hold).action, "hold");
        compare(HeadsetButton.timeout(s, hold + 500).action, "", "one hold per press");

        const up = HeadsetButton.release(s, hold + 700);
        compare(up.action, "");
        compare(up.timerMs, 0, "nothing to count after a hold");
    }

    function test_aHoldDropsThePressesBeforeIt() {
        const s = HeadsetButton.initial();
        click(s, 0);
        HeadsetButton.press(s, 200);
        compare(HeadsetButton.timeout(s, 200 + hold).action, "hold");
        HeadsetButton.release(s, 200 + hold + 100);
        compare(HeadsetButton.timeout(s, 200 + hold + 100 + multi).action, "",
                "the press before the hold is not played afterwards");
    }

    function test_aReleaseWithoutAPressDoesNothing() {
        const s = HeadsetButton.initial();
        const up = HeadsetButton.release(s, 0);
        compare(up.action, "");
        compare(up.timerMs, 0);
        compare(s.count, 0);
    }

    function test_theTimesAre2xHoldAndAndroidsMultiPress() {
        compare(HeadsetButton.holdMs, 2000);
        compare(HeadsetButton.multiPressMs, 400);
    }

    function test_whatThePressesMean() {
        compare(HeadsetButton.actionFor(0), "");
        compare(HeadsetButton.actionFor(1), "playPause");
        compare(HeadsetButton.actionFor(2), "next");
        compare(HeadsetButton.actionFor(3), "previous");
        compare(HeadsetButton.actionFor(4), "");
    }
}
