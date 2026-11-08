import QtQuick 2.0
import QtTest 1.0

import "../qml/LockScreen"

/*
 * A right passcode or pattern hands luna-authmanager's unlock token on with
 * the unlock, for LockScreen to give com.palm.display; a reply without one
 * (an older authmanager) unlocks with an empty token, which the display
 * refuses while a passcode is set. Replies are fed in as the bus would.
 */
Item {
    width: 480
    height: 800

    PatternLock { id: pattern }
    PinPasswordLock { id: pin }

    SignalSpy { id: patternUnlocked; target: pattern; signalName: "unlock" }
    SignalSpy { id: pinUnlocked; target: pin; signalName: "unlock" }

    TestCase {
        name: "LockToken"
        when: windowShown

        function cleanup() {
            patternUnlocked.clear();
            pinUnlocked.clear();
        }

        function test_a_right_pattern_passes_the_token_on() {
            pattern.handlePatternResult({ payload: JSON.stringify(
                { returnValue: true, unlockToken: "0123456789abcdef0123456789abcdef" }) });
            compare(patternUnlocked.count, 1);
            compare(patternUnlocked.signalArguments[0][0], "0123456789abcdef0123456789abcdef");
        }

        function test_a_right_pin_passes_the_token_on() {
            pin.handlePasscodeResult({ payload: JSON.stringify(
                { returnValue: true, unlockToken: "fedcba9876543210fedcba9876543210" }) });
            compare(pinUnlocked.count, 1);
            compare(pinUnlocked.signalArguments[0][0], "fedcba9876543210fedcba9876543210");
        }

        function test_no_token_is_an_empty_one() {
            pin.handlePasscodeResult({ payload: JSON.stringify({ returnValue: true }) });
            compare(pinUnlocked.count, 1);
            compare(pinUnlocked.signalArguments[0][0], "");
        }

        function test_a_wrong_one_does_not_unlock() {
            pin.handlePasscodeResult({ payload: JSON.stringify({ returnValue: false, retriesLeft: 4 }) });
            pattern.handlePatternResult({ payload: JSON.stringify({ returnValue: false }) });
            compare(pinUnlocked.count, 0);
            compare(patternUnlocked.count, 0);
        }
    }
}
