import QtQuick 2.0
import QtTest 1.0

import "../qml"

/*
 * The shutdown animation is up, and its orb turns, while the device is going
 * down, and neither once a failed shutdown is cancelled.
 */
Item {
    width: 480
    height: 800

    ShutdownScreen { id: screen }

    TestCase {
        name: "ShutdownScreen"
        when: windowShown

        function orb() {
            for (var i = 0; i < screen.children.length; i++)
                if (screen.children[i].hasOwnProperty("orbRadius"))
                    return screen.children[i];
            return null;
        }

        function cleanup() {
            screen.cancel();
        }

        function test_hidden_until_shutdown() {
            verify(!screen.visible);
            verify(!orb().running);
        }

        function test_shown_while_going_down() {
            screen.start();
            verify(screen.visible);
            verify(orb().running);
        }

        function test_cancel_hides_it() {
            screen.start();
            screen.cancel();
            verify(!screen.visible);
            verify(!orb().running);
        }
    }
}
