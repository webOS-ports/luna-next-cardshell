import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/Notifications"

/*
 * A popup alert's "sound" and "soundclass" attributes, which reach the shell as
 * window properties: played once when the window comes, cut off when it goes,
 * and an alert that asks for no sound stays silent - the incoming call and the
 * alarm sound for themselves. Run against luneos-components' compositor mock.
 */
Item {
    width: 480
    height: 800

    Compositor { id: compositor }

    Component {
        id: alertWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_SYSTEM_UI"
            property var windowProperties: ({})
            function changeSize(size) {}
        }
    }

    AlertWindowsArea {
        id: area
        width: 480
        compositorInstance: compositor
    }

    TestCase {
        name: "PopupAlertSound"
        when: windowShown

        property var sounds: null

        function initTestCase() {
            for (var i = 0; i < area.children.length; i++) {
                if (area.children[i].objectName === "soundNotifications")
                    sounds = area.children[i];
            }
            verify(sounds, "AlertWindowsArea has its SoundNotifications");
            sounds.fileExists = function(path) { return true; };
            sounds.callService = function(url, request, onReply) {};
            sounds.playerComponent = fakePlayer;
        }

        Component {
            id: fakePlayer
            QtObject {
                property string path
                property string sink
                property bool looping
                property int durationMs: -1
                property string playbackId: ""
                property bool heldByAudiod: false
                signal finished()
                signal limitReached()
                function playLocally() {}
                function startLimit(ms) {}
                function stop() { finished(); }
                function finish() { finished(); }
            }
        }

        function open(properties) {
            properties["LuneOS_window"] = "popupalert";
            var window = alertWindow.createObject(compositor, { height: 100, windowProperties: properties });
            compositor.surfaceModel.append({ obj: window });
            return window;
        }

        function closeAll() {
            while (compositor.surfaceModel.count > 0)
                compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        }

        function cleanup() {
            closeAll();
        }

        function test_the_battery_alert_sounds() {
            open({ "LuneOS_sound": "/usr/palm/sounds/battery_low.mp3", "LuneOS_soundclass": "alerts" });
            compare(sounds.players.length, 1);
            compare(sounds.players[0].path, "/usr/palm/sounds/battery_low.mp3");
            compare(sounds.players[0].sink, "palerts");
        }

        function test_a_ringing_popup_loops() {
            open({ "LuneOS_soundclass": "ringtones" });
            compare(sounds.players.length, 1);
            verify(sounds.players[0].looping);
        }

        function test_a_reminder_sounds_on_its_class() {
            open({ "LuneOS_soundclass": "calendar" });
            compare(sounds.players.length, 1);
            compare(sounds.players[0].sink, "palerts");
        }

        function test_an_alert_asking_for_nothing_is_silent() {
            open({});
            compare(sounds.players.length, 0);
            open({ "LuneOS_overLockScreen": "true" });
            compare(sounds.players.length, 0);
        }

        function test_none_is_silent() {
            open({ "LuneOS_soundclass": "none" });
            compare(sounds.players.length, 0);
        }

        function test_a_second_alert_does_not_replay_the_first() {
            open({ "LuneOS_soundclass": "calendar" });
            open({ "LuneOS_soundclass": "alerts" });
            compare(sounds.players.length, 2);
        }

        function test_the_sound_stops_with_the_window() {
            open({ "LuneOS_sound": "/usr/palm/sounds/battery_low.mp3", "LuneOS_soundclass": "alerts" });
            compare(sounds.players.length, 1);
            closeAll();
            compare(sounds.players.length, 0);
        }

        function test_a_reminder_back_from_snooze_sounds_again() {
            open({ "LuneOS_soundclass": "calendar" });
            closeAll();
            open({ "LuneOS_soundclass": "calendar" });
            compare(sounds.players.length, 1);
        }
    }
}
