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

    function exists(path) {
        return ["/usr/palm/sounds/battery_low.mp3", "/usr/palm/sounds/alert.wav",
                "/usr/palm/sounds/notification.wav", "/usr/palm/sounds/ringtone.mp3",
                "/media/internal/ringtones/My Tone.mp3"].indexOf(path) !== -1;
    }

    readonly property var tones: ({
        ringtone: "/usr/palm/sounds/ringtone.mp3",
        alerttone: "/usr/palm/sounds/alert.wav",
        notificationtone: "/usr/palm/sounds/notification.wav",
        fallback: "/usr/palm/sounds/alert.wav"
    })

    function test_nothing_and_none_play_nothing() {
        compare(NotificationSound.resolve("", "", tones, exists), null);
        compare(NotificationSound.resolve("none", "", tones, exists), null);
        compare(NotificationSound.resolve("none", "/usr/palm/sounds/alert.wav", tones, exists), null);
    }

    function test_vibrate_is_no_sound() {
        compare(NotificationSound.resolve("vibrate", "", tones, exists).vibrate, true);
        compare(NotificationSound.resolve("vibrate", "/usr/palm/sounds/alert.wav", tones, exists).path, undefined);
    }

    function test_the_battery_alert() {
        var sound = NotificationSound.resolve("alerts", "/usr/palm/sounds/battery_low.mp3", tones, exists);
        compare(sound.path, "/usr/palm/sounds/battery_low.mp3");
        compare(NotificationSound.sinkFor(sound.streamClass), "palerts");
    }

    function test_a_class_alone_takes_the_users_tone() {
        compare(NotificationSound.resolve("calendar", "", tones, exists).path, tones.alerttone);
        compare(NotificationSound.resolve("alerts", "", tones, exists).path, tones.alerttone);
        compare(NotificationSound.resolve("alarm", "", tones, exists).path, tones.alerttone);
        compare(NotificationSound.resolve("ringtones", "", tones, exists).path, tones.ringtone);
        compare(NotificationSound.resolve("notifications", "", tones, exists).path, tones.notificationtone);
        compare(NotificationSound.resolve("nonsense", "", tones, exists).path, tones.notificationtone);
    }

    function test_a_file_alone_is_a_notification() {
        var sound = NotificationSound.resolve("", "/media/internal/ringtones/My Tone.mp3", tones, exists);
        compare(sound.path, "/media/internal/ringtones/My Tone.mp3");
        compare(sound.streamClass, "notifications");
    }

    function test_a_missing_or_forbidden_file_gives_way_to_the_tone() {
        compare(NotificationSound.resolve("alerts", "/media/internal/gone.mp3", tones, exists).path, tones.alerttone);
        var everything = function(path) { return true; };
        compare(NotificationSound.resolve("alerts", "/dev/zero", tones, everything).path, tones.alerttone);
        compare(NotificationSound.resolve("alerts", "/etc/shadow.mp3", tones, everything).path, tones.alerttone);
    }

    function test_a_missing_tone_falls_back() {
        var noTone = { ringtone: "/media/internal/gone.mp3", alerttone: "", notificationtone: "",
                       fallback: "/usr/palm/sounds/alert.wav" };
        compare(NotificationSound.resolve("ringtones", "", noTone, exists).path, noTone.fallback);
        compare(NotificationSound.resolve("alerts", "", noTone, exists).path, noTone.fallback);
    }

    function test_nothing_at_all_to_play() {
        var nothing = function(path) { return false; };
        compare(NotificationSound.resolve("alerts", "", tones, nothing), null);
    }

    function test_playable_paths() {
        verify(NotificationSound.isPlayablePath("/usr/palm/sounds/battery_low.mp3"));
        verify(NotificationSound.isPlayablePath("/usr/palm/applications/com.palm.app.email/sounds/emailreceived.mp3"));
        verify(NotificationSound.isPlayablePath("/media/cryptofs/apps/usr/palm/applications/a.b/x.WAV"));
        verify(NotificationSound.isPlayablePath("/media/internal/ringtones/My Tone.m4a"));
        verify(NotificationSound.isPlayablePath("/media/internal/..hidden/a..b.ogg"));
    }

    function test_paths_that_are_not() {
        var bad = ["", null, undefined, 7, [], {}, "relative.mp3", "/dev/zero", "/dev/snd/x.mp3",
                   "/proc/self/mem", "/etc/shadow.mp3", "/media/internal/a.txt",
                   "/media/internal/../../etc/x.mp3", "/usr/palm/sounds/../../../etc/x.wav",
                   "/usr/palm/sounds/a\nb.mp3", "/media/internalx/a.mp3",
                   "/media/cryptofs/spotify-webos/a.mp3",
                   "/media/internal/" + new Array(5000).join("a") + ".mp3"];
        for (var i = 0; i < bad.length; i++)
            verify(!NotificationSound.isPlayablePath(bad[i]), String(bad[i]).slice(0, 40));
    }

    function test_durations() {
        compare(NotificationSound.durationFor("alerts", 3000, 5000), 3000);
        compare(NotificationSound.durationFor("notifications", 3000, 5000), 3000);
        compare(NotificationSound.durationFor("alerts", -1, 5000), -1);
        compare(NotificationSound.durationFor("calendar", 0, 5000), -1);
        compare(NotificationSound.durationFor("notifications", -1, 5000), 5000);
    }

    function test_only_a_ringtone_loops() {
        verify(NotificationSound.loopsFor("ringtones"));
        verify(!NotificationSound.loopsFor("calendar"));
        verify(!NotificationSound.loopsFor("alarm"));
    }

    function test_url() {
        compare(NotificationSound.urlFor("/media/internal/My #1?.mp3"),
                "file:///media/internal/My%20%231%3F.mp3");
    }

    function test_each_window_sounds_once_and_stops_when_it_goes() {
        var a = { name: "a" };
        var b = { name: "b" };
        var started = [];
        var stopped = [];
        var start = function(window) { started.push(window); return "handle-" + window.name; };
        var stop = function(handle) { stopped.push(handle); };

        var known = NotificationSound.trackAlerts([a], [], start, stop);
        compare(started.length, 1);
        known = NotificationSound.trackAlerts([a, b], known, start, stop);
        compare(started.length, 2);
        compare(stopped.length, 0);
        // a goes: b keeps sounding, and is not started again.
        known = NotificationSound.trackAlerts([b], known, start, stop);
        compare(started.length, 2);
        compare(stopped, ["handle-a"]);
        known = NotificationSound.trackAlerts([], known, start, stop);
        compare(stopped, ["handle-a", "handle-b"]);
        compare(known.length, 0);
    }

    function test_a_silent_window_is_not_asked_again() {
        var a = {};
        var starts = 0;
        var start = function(window) { starts++; return null; };
        var known = NotificationSound.trackAlerts([a], [], start, function(handle) { fail("stopped"); });
        known = NotificationSound.trackAlerts([a], known, start, function(handle) { fail("stopped"); });
        compare(starts, 1);
        NotificationSound.trackAlerts([], known, start, function(handle) { fail("stopped"); });
    }
}
