import QtQuick 2.0
import QtTest 1.0

import "../qml/LockScreen"

/*
 * The padlock's one-line biometric status ("Checking...") shows for a couple
 * of seconds, goes when cleared, and gives way to the lockout message.
 */
Item {
    width: 480
    height: 800

    PadLock { id: padLock }

    TestCase {
        name: "PadLockStatus"
        when: windowShown

        function textItem(pred) {
            for (var i = 0; i < padLock.children.length; i++) {
                var c = padLock.children[i];
                if (c.hasOwnProperty("wrapMode") && pred(c))
                    return c;
            }
            return null;
        }
        function status() {
            return textItem(function(t) { return t.text === "Checking" || t.text === "Face not recognized"; });
        }
        function lockout() {
            return textItem(function(t) { return t.text.indexOf("Too many attempts") === 0; });
        }

        // What dragging the pad does to the lockout message.
        function cleanup() {
            var l = lockout();
            if (l)
                l.visible = false;
            padLock.clearBiometricStatus();
        }

        function test_shows_then_goes() {
            padLock.showBiometricStatus("Checking");
            verify(status().visible);
            tryVerify(function() { return !status().visible; }, 4000);
        }

        function test_clear_hides_it() {
            padLock.showBiometricStatus("Checking");
            padLock.clearBiometricStatus();
            verify(!status().visible);
        }

        function test_an_empty_status_hides_it() {
            padLock.showBiometricStatus("Checking");
            var item = status();
            padLock.showBiometricStatus("");
            verify(!item.visible);
        }

        function test_lockout_wins() {
            padLock.showBiometricStatus("Checking");
            var item = status();
            padLock.showBiometricLockout("pin", "fingerprint");
            verify(lockout().visible);
            verify(!item.visible);
            padLock.showBiometricStatus("Face not recognized");
            verify(!item.visible);
        }
    }
}
