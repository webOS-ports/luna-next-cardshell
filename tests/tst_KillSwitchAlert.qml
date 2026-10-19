import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1

import "../qml/Notifications"

/*
 * A hardware privacy switch that moves shows its icon for two seconds; a
 * state that says nothing ("unknown") shows nothing.
 */
Item {
    width: 480
    height: 800

    KillSwitchAlert { id: alert }

    TestCase {
        name: "KillSwitchAlert"
        when: windowShown

        function image() {
            for (var i = 0; i < alert.children.length; i++)
                if (alert.children[i].hasOwnProperty("fillMode"))
                    return alert.children[i];
            return null;
        }

        function cleanup() {
            tryVerify(function() { return !alert.visible; }, 3000);
        }

        function test_shows_the_switch_that_moved() {
            verify(!alert.visible);
            alert.showSwitch("camera", "blocked");
            verify(alert.visible);
            verify(String(image().source).indexOf("camera_off.png") >= 0);
            compare(image().height, Units.gu(9.6));
        }

        function test_hides_after_a_while() {
            alert.showSwitch("microphone", "open");
            verify(alert.visible);
            tryVerify(function() { return !alert.visible; }, 3000);
        }

        function test_unknown_shows_nothing() {
            alert.showSwitch("camera", "unknown");
            verify(!alert.visible);
        }
    }
}
