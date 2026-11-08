import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * The real player: whatever becomes of a sound it has to report that it is
 * done, or the slot stays taken. The host has none of the device's sinks, so
 * which sink is taken is the device test's to show.
 */
Item {
    Component {
        id: playerComponent
        SoundNotificationPlayer {}
    }

    SignalSpy { id: finished; signalName: "finished" }

    TestCase {
        name: "SoundNotificationPlayer"

        function make(path, durationMs) {
            var player = playerComponent.createObject(null, { path: path, sink: "no-such-sink", durationMs: durationMs });
            finished.clear();
            finished.target = player;
            return player;
        }

        function test_a_missing_file_finishes() {
            ignoreWarning(/no sink no-such-sink/);
            ignoreWarning(/NotificationSound: cannot play/);
            var player = make("/no/such/file.mp3", -1);
            player.playLocally();
            finished.wait(5000);
            compare(finished.count, 1);
            player.destroy();
        }

        function test_stop_finishes_once() {
            var player = make(Qt.resolvedUrl("data/silence-200ms.wav").toString().replace("file://", ""), -1);
            player.stop();
            player.stop();
            compare(finished.count, 1);
            player.destroy();
        }

        function test_a_limit_reports() {
            ignoreWarning(/no sink no-such-sink/);
            var player = make(Qt.resolvedUrl("data/silence-200ms.wav").toString().replace("file://", ""), 50);
            var spy = Qt.createQmlObject('import QtTest 1.0; SignalSpy { signalName: "limitReached" }', player);
            spy.target = player;
            player.playLocally();
            spy.wait(3000);
            compare(spy.count, 1);
            player.stop();
            compare(finished.count, 1);
            player.destroy();
        }
    }
}
