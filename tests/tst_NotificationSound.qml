import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications/NotificationSound.js" as NotificationSound

/*
 * NotificationSound: a banner's sound goes to audiod on its class's sink, so
 * audiod can lower the music under it, and only plays on the default stream
 * when audiod cannot take the file or turns it down.
 */
TestCase {
    name: "NotificationSound"

    property var requests: []
    property int localPlays: 0

    function init() {
        requests = [];
        localPlays = 0;
    }

    // An audiod that answers every request with `response`.
    function audiodReplying(response) {
        return function(request, onReply) {
            requests.push(request);
            onReply(response);
        };
    }

    function playLocally() {
        localPlays++;
    }

    function test_stream_classes() {
        compare(NotificationSound.streamClassFor("alert"), "alerts");
        compare(NotificationSound.streamClassFor("notification"), "notifications");
        compare(NotificationSound.streamClassFor("ringtone"), "ringtones");
        compare(NotificationSound.streamClassFor("calendar"), "calendar");
        compare(NotificationSound.streamClassFor("alarm"), "alarm");
        compare(NotificationSound.streamClassFor("feedback"), "feedback");
        compare(NotificationSound.streamClassFor(""), "notifications");
        compare(NotificationSound.streamClassFor(undefined), "notifications");
        compare(NotificationSound.streamClassFor("media"), "notifications");
    }

    // As palm-policy routes them: notifications and reminders are alerts, an
    // alarm rings like the phone.
    function test_sinks() {
        compare(NotificationSound.sinkFor("alerts"), "palerts");
        compare(NotificationSound.sinkFor("notifications"), "palerts");
        compare(NotificationSound.sinkFor("calendar"), "palerts");
        compare(NotificationSound.sinkFor("ringtones"), "pringtones");
        compare(NotificationSound.sinkFor("alarm"), "pringtones");
        compare(NotificationSound.sinkFor("feedback"), "pfeedback");
    }

    function test_a_wav_goes_to_audiod_on_palerts() {
        NotificationSound.play("/usr/palm/sounds/notification.wav", "notifications",
                               audiodReplying({ returnValue: true, playbackId: "x" }), playLocally);
        compare(requests.length, 1);
        compare(requests[0].fileName, "/usr/palm/sounds/notification.wav");
        compare(requests[0].sink, "palerts");
        // The WAV header says its format.
        verify(!requests[0].hasOwnProperty("format"));
        compare(localPlays, 0);
    }

    function test_a_ringtone_goes_to_pringtones() {
        NotificationSound.play("/usr/palm/sounds/phone.wav", "ringtones",
                               audiodReplying({ returnValue: true }), playLocally);
        compare(requests[0].sink, "pringtones");
        compare(localPlays, 0);
    }

    function test_a_raw_pcm_says_its_format() {
        NotificationSound.play("/usr/share/systemsounds/sysmgr_notification.pcm", "notifications",
                               audiodReplying({ returnValue: true }), playLocally);
        compare(requests[0].format, "PA_SAMPLE_S16LE");
        compare(requests[0].sampleRate, 44100);
        compare(requests[0].channels, 1);
    }

    function test_an_mp3_plays_locally() {
        NotificationSound.play("/usr/palm/sounds/ringtone.mp3", "ringtones",
                               audiodReplying({ returnValue: true }), playLocally);
        compare(requests.length, 0);
        compare(localPlays, 1);
    }

    function test_refused_by_audiod_plays_locally() {
        ignoreWarning(/NotificationSound: audiod did not play .*Invalid file format/);
        NotificationSound.play("/media/internal/tone.wav", "alerts",
                               audiodReplying({ returnValue: false, errorText: "Invalid file format" }),
                               playLocally);
        compare(requests.length, 1);
        compare(localPlays, 1);
    }

    function test_no_reply_plays_locally() {
        ignoreWarning(/NotificationSound: audiod did not play .*no reply/);
        NotificationSound.play("/usr/palm/sounds/alert.wav", "alerts", audiodReplying(null), playLocally);
        compare(localPlays, 1);
    }

    function test_no_path_plays_nothing() {
        NotificationSound.play("", "alerts", audiodReplying({ returnValue: true }), playLocally);
        compare(requests.length, 0);
        compare(localPlays, 0);
    }
}
