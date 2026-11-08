import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * What an app's playSoundNotification and a popup alert come to: audiod for
 * what audiod plays, this shell's own player on the class's sink for the rest,
 * and for anything an app sends that makes no sense, nothing.
 */
Item {
    id: root

    property var calls: []
    property var audiodReply: ({ returnValue: true, playbackId: "id-1" })

    QtObject {
        id: fakeTones
        property string ringtoneFullPath: "/usr/palm/sounds/ringtone.mp3"
        property string alerttoneFullPath: "/usr/palm/sounds/alert.wav"
        property string notificationtoneFullPath: "/usr/palm/sounds/notification.wav"
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
            property bool playedLocally: false
            property bool stopped: false
            property int limit: 0
            signal finished()
            signal limitReached()
            function playLocally() { playedLocally = true; }
            function startLimit(ms) { limit = ms; }
            function stop() { stopped = true; finished(); }
            function finish() { finished(); }
        }
    }

    SoundNotifications {
        id: sounds
        tones: fakeTones
        playerComponent: fakePlayer
        callService: function(url, request, onReply) {
            root.calls.push({ url: url, request: request });
            if (onReply)
                onReply(root.audiodReply);
        }
        fileExists: function(path) {
            return path !== "/media/internal/gone.mp3";
        }
    }

    TestCase {
        name: "SoundNotifications"

        function init() {
            root.calls = [];
            root.audiodReply = { returnValue: true, playbackId: "id-1" };
            sounds.players.slice().forEach(function(player) { sounds.stop(player); });
            root.calls = [];
        }

        function callsTo(url) {
            return root.calls.filter(function(call) { return call.url === url; });
        }

        function test_email_system_sound_plays_on_palerts_here() {
            var player = sounds.play("alerts", "/usr/palm/applications/com.palm.app.email/sounds/emailreceived.mp3", 3000, false);
            verify(player.playedLocally);
            compare(player.sink, "palerts");
            compare(player.durationMs, 3000);
            compare(root.calls.length, 0);
        }

        function test_a_wav_goes_to_audiod_and_is_let_go() {
            var player = sounds.play("alerts", "/usr/palm/sounds/alert.wav", -1, false);
            var plays = callsTo("luna://com.webos.service.audio/playSound");
            compare(plays.length, 1);
            compare(plays[0].request.sink, "palerts");
            verify(!player.playedLocally);
            compare(player.playbackId, "id-1");
            compare(player.limit, sounds.audiodHoldMs);
            // The hold runs out: the sound is left to finish.
            player.limitReached();
            compare(callsTo("luna://com.webos.service.audio/controlPlayback").length, 0);
            verify(!player.stopped);
            compare(sounds.players.length, 0);
        }

        function test_a_limit_stops_audiod() {
            var player = sounds.play("alerts", "/usr/palm/sounds/alert.wav", 1000, false);
            compare(player.limit, 1000);
            player.limitReached();
            var controls = callsTo("luna://com.webos.service.audio/controlPlayback");
            compare(controls.length, 1);
            compare(controls[0].request.playbackId, "id-1");
            compare(controls[0].request.requestType, "stop");
        }

        function test_refused_by_audiod_plays_here() {
            root.audiodReply = { returnValue: false, errorText: "no" };
            ignoreWarning(/NotificationSound: audiod did not play/);
            var player = sounds.play("alerts", "/usr/palm/sounds/alert.wav", -1, false);
            verify(player.playedLocally);
        }

        function test_a_ringtone_an_app_asked_for_plays_once() {
            var player = sounds.play("ringtones", "", -1, false);
            verify(player.playedLocally);
            verify(!player.looping);
            compare(player.sink, "pringtones");
            sounds.stop(player);
            compare(sounds.players.length, 0);
        }

        function test_a_ringtone_from_the_service_does_not_loop() {
            sounds.handlePlay({ payload: '{"soundClass":"ringtones"}' });
            compare(sounds.players.length, 1);
            verify(!sounds.players[0].looping);
            sounds.stop(sounds.players[0]);
        }

        function test_a_popup_ringtone_loops_here_until_stopped() {
            var player = sounds.play("ringtones", "", -1, false, true);
            verify(player.playedLocally);
            verify(player.looping);
            compare(player.sink, "pringtones");
            compare(player.path, fakeTones.ringtoneFullPath);
            sounds.stop(player);
            verify(player.stopped);
            compare(sounds.players.length, 0);
        }

        function test_vibrate() {
            compare(sounds.play("vibrate", "", -1, false), null);
            compare(callsTo("luna://com.palm.vibrate/vibrate").length, 1);
            compare(sounds.players.length, 0);
        }

        function test_none() {
            compare(sounds.play("none", "", -1, false), null);
            compare(root.calls.length, 0);
        }

        function test_no_more_than_the_maximum() {
            for (var i = 0; i < sounds.maxPlayers; i++)
                verify(sounds.play("alerts", "/usr/palm/sounds/x.mp3", -1, false));
            ignoreWarning(/NotificationSound: too many sounds/);
            compare(sounds.play("alerts", "/usr/palm/sounds/x.mp3", -1, false), null);
            compare(sounds.players.length, sounds.maxPlayers);
        }

        function test_a_finished_sound_makes_room() {
            var player = sounds.play("alerts", "/usr/palm/sounds/x.mp3", -1, false);
            compare(sounds.players.length, 1);
            player.finished();
            compare(sounds.players.length, 0);
        }

        function test_wakeup_lights_the_display_for_the_sound() {
            var player = sounds.play("alerts", "/usr/palm/sounds/x.mp3", -1, true);
            var alerts = callsTo("luna://com.palm.display/control/alert");
            compare(alerts.length, 1);
            compare(alerts[0].request.status, "generic-activated");
            player.finished();
            alerts = callsTo("luna://com.palm.display/control/alert");
            compare(alerts.length, 2);
            compare(alerts[1].request.status, "generic-deactivated");
        }

        function test_no_wakeup_leaves_the_display_alone() {
            sounds.play("alerts", "/usr/palm/sounds/x.mp3", -1, false);
            compare(callsTo("luna://com.palm.display/control/alert").length, 0);
        }

        function test_stopping_what_is_not_playing() {
            sounds.stop(null);
            sounds.stop({});
            compare(root.calls.length, 0);
        }

        function test_bus_request() {
            var reply = JSON.parse(sounds.handlePlay({ payload: JSON.stringify({
                appId: "com.palm.app.email", soundClass: "alerts",
                soundFile: "/usr/palm/sounds/x.mp3", duration: 3000, wakeup: false }) }));
            verify(reply.returnValue);
            compare(sounds.players.length, 1);
            compare(sounds.players[0].durationMs, 3000);
        }

        function test_bad_bus_requests() {
            var bad = ["", "[]", "null", "1", "\"x\"", "{", "[{}]"];
            for (var i = 0; i < bad.length; i++)
                verify(!JSON.parse(sounds.handlePlay({ payload: bad[i] })).returnValue, bad[i]);
            compare(sounds.players.length, 0);
            compare(root.calls.length, 0);
        }

        function test_members_of_the_wrong_type() {
            sounds.handlePlay({ payload: '{"soundClass":1,"soundFile":[],"duration":{},"wakeup":"yes"}' });
            compare(sounds.players.length, 0);
            compare(root.calls.length, 0);

            sounds.handlePlay({ payload: '{"soundClass":"alerts","soundFile":{},"duration":"x","wakeup":"yes"}' });
            compare(sounds.players.length, 1);
            compare(sounds.players[0].path, fakeTones.alerttoneFullPath);
            compare(callsTo("luna://com.palm.display/control/alert").length, 0);
        }
    }
}
