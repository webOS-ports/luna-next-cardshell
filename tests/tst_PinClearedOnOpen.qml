import QtQuick 2.0
import QtTest 1.0

import "../qml/LockScreen"

/*
 * Digits typed into the PIN pad and then left there - the device unlocked
 * by a finger or a face instead, or the screen locked again - must be gone
 * when the pad is next shown. Only a matching passcode used to clear them.
 */
Item {
    width: 480
    height: 800

    PinPasswordLock { id: pin; visible: false }

    function findField(item) {
        for (var i = 0; i < item.children.length; ++i) {
            var child = item.children[i];
            if (child.enteredText !== undefined && child.clearAll !== undefined)
                return child;
        }
        return null;
    }

    TestCase {
        name: "PinClearedOnOpen"
        when: windowShown

        function cleanup() {
            pin.lockoutLeft = 0;
            pin.visible = false;
        }

        function test_digits_left_behind_are_cleared_when_the_pad_opens() {
            var field = findField(pin);
            verify(field !== null);
            pin.visible = true;
            field.keyInput("1", true);
            field.keyInput("2", true);
            compare(field.enteredText, "12");

            // Unlocked by a finger: the pad goes away without a passcode.
            pin.visible = false;
            compare(field.enteredText, "12");

            pin.visible = true;
            compare(field.enteredText, "");
        }

        function hasTitle(text) {
            for (var i = 0; i < pin.children.length; ++i)
                if (pin.children[i].text === text)
                    return true;
            return false;
        }

        // Reopening during a lockout must not put "Device Locked" back over
        // the countdown.
        function test_a_running_lockout_keeps_its_title() {
            pin.visible = true;
            pin.startLockout(30);
            pin.visible = false;
            pin.visible = true;
            verify(pin.lockedOut);
            verify(hasTitle("Too many tries"));
        }

        function test_the_title_comes_back_after_a_wrong_pin() {
            pin.visible = true;
            pin.handlePasscodeResult({ payload: JSON.stringify({ returnValue: false, retriesLeft: 4 }) });
            verify(hasTitle("PIN incorrect"));
            pin.visible = false;
            pin.visible = true;
            verify(hasTitle("Device Locked"));
        }
    }
}
