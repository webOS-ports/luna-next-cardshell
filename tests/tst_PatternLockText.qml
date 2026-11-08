import QtQuick 2.0
import QtTest 1.0

import "../qml/LockScreen"

/*
 * What the pattern lock says: "Draw your pattern", "Pattern incorrect" after a
 * wrong one until the next is started, and a countdown while luna-authmanager
 * is locked out, back to "Device Locked" once it is over. Replies are fed to
 * handlePatternResult() as the bus would.
 */
Item {
    width: 480
    height: 800

    PatternLock { id: lock }

    TestCase {
        name: "PatternLockText"
        when: windowShown

        function texts() {
            var t = [];
            for (var i = 0; i < lock.children.length; i++)
                if (lock.children[i].hasOwnProperty("wrapMode"))
                    t.push(lock.children[i]);
            return t;
        }
        function title() { return texts().filter(function(t) { return t.font.bold; })[0].text; }
        function hint() { return texts().filter(function(t) { return !t.font.bold; })[0].text; }
        function grid() {
            for (var i = 0; i < lock.children.length; i++)
                if (lock.children[i].hasOwnProperty("drawing"))
                    return lock.children[i];
            return null;
        }
        function reply(r) {
            lock.handlePatternResult({ payload: JSON.stringify(r) });
        }

        function cleanup() {
            lock.lockoutLeft = 0;
            lock.resetEntry();
        }

        function test_starts_asking_for_the_pattern() {
            compare(title(), "Device Locked");
            compare(hint(), "Draw your pattern");
        }

        function test_a_wrong_pattern_until_the_next_is_started() {
            reply({ returnValue: false });
            tryCompare(lock, "_mismatched", true, 2000);
            compare(hint(), "Pattern incorrect. Try again.");
            grid().started();
            compare(hint(), "Draw your pattern");
        }

        function test_counts_down_a_lockout() {
            reply({ returnValue: false, lockedOut: true, lockoutSeconds: 2 });
            compare(title(), "Too many tries");
            compare(hint(), "Try again in 2 seconds");
            tryCompare(lock, "lockoutLeft", 1, 2000);
            compare(hint(), "Try again in 1 second");
            tryCompare(lock, "lockoutLeft", 0, 2000);
            compare(title(), "Device Locked");
            compare(hint(), "Draw your pattern");
        }

        function test_a_lockout_after_a_wrong_pattern_ends_clean() {
            reply({ returnValue: false });
            tryCompare(lock, "_mismatched", true, 2000);
            reply({ returnValue: false, lockedOut: true, lockoutSeconds: 1 });
            tryCompare(lock, "lockoutLeft", 0, 2000);
            compare(hint(), "Draw your pattern");
        }
    }
}
