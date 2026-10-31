import QtQuick 2.0
import QtTest 1.0

import "../qml/LockScreen"

/*
 * A pad that opens while luna-authmanager is locked out - after a reboot,
 * say, before anything has been tried - learns so from getDeviceLockMode
 * and counts down from the start, instead of taking a passcode that the
 * daemon refuses unseen. Replies are fed in as the bus would; the mock
 * LunaService answers the call made on opening with an older reply that
 * has no lockout in it.
 */
Item {
    width: 480
    height: 800

    PatternLock { id: pattern; visible: false }
    PinPasswordLock { id: pin; visible: false }

    function lockModeReply(fields) {
        var r = { returnValue: true, lockMode: "pin", policyState: "none", retriesLeft: 0 };
        for (var k in fields)
            r[k] = fields[k];
        return { payload: JSON.stringify(r) };
    }

    TestCase {
        name: "LockoutOnOpen"
        when: windowShown

        function cleanup() {
            pin.lockoutLeft = 0;
            pattern.lockoutLeft = 0;
            pin.visible = false;
            pattern.visible = false;
        }

        function test_a_running_lockout_locks_the_pin_pad() {
            pin.handleLockModeResult(lockModeReply({ lockedOut: true, lockoutSeconds: 20 }));
            verify(pin.lockedOut);
            compare(pin.lockoutLeft, 20);
        }

        function test_a_running_lockout_locks_the_pattern_pad() {
            pattern.handleLockModeResult(lockModeReply({ lockMode: "pattern", lockedOut: true, lockoutSeconds: 45 }));
            verify(pattern.lockedOut);
            compare(pattern.lockoutLeft, 45);
        }

        function test_no_lockout_leaves_the_pads_open() {
            pin.handleLockModeResult(lockModeReply({ lockedOut: false, lockoutSeconds: 0 }));
            pattern.handleLockModeResult(lockModeReply({ lockedOut: false, lockoutSeconds: 0 }));
            verify(!pin.lockedOut);
            verify(!pattern.lockedOut);
        }

        // An authmanager from before the lockout was reported here.
        function test_an_older_reply_leaves_the_pads_open() {
            pin.handleLockModeResult(lockModeReply({}));
            pattern.handleLockModeResult(lockModeReply({}));
            verify(!pin.lockedOut);
            verify(!pattern.lockedOut);
        }

        // Opening asks; the mock's answer carries no lockout, so the pads
        // stay usable rather than locking on a reply they cannot read.
        function test_opening_with_no_lockout_keeps_the_pads_usable() {
            pin.visible = true;
            pattern.visible = true;
            verify(!pin.lockedOut);
            verify(!pattern.lockedOut);
        }

        // The daemon's figure wins over a countdown already running.
        function test_a_later_reply_sets_the_time_left() {
            pin.handleLockModeResult(lockModeReply({ lockedOut: true, lockoutSeconds: 30 }));
            pin.handleLockModeResult(lockModeReply({ lockedOut: true, lockoutSeconds: 12 }));
            compare(pin.lockoutLeft, 12);
        }
    }
}
