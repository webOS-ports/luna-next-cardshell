import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import QtMultimedia 6.3

import "../qml/Notifications"

/*
 * A warning stays up until it is acknowledged, wakes the display, and its tone
 * never sounds during a call: it waits for the call to end, if the warning is
 * still there by then.
 */
Item {
    width: 480
    height: 800

    property var calls: []
    property var vibrations: []
    property var masterStatus: null
    property var muteCalls: []

    CellBroadcastAlert {
        id: alert
        anchors.fill: parent

        function callService(uri, payload) {
            calls = calls.concat([uri]);
            if (payload.duration)
                vibrations = vibrations.concat([payload.duration]);
        }

        function readMaster(onStatus) {
            onStatus(masterStatus);
        }

        function setMasterMute(soundOutput, mute) {
            muteCalls = muteCalls.concat([soundOutput + ":" + mute]);
        }
    }

    TestCase {
        name: "CellBroadcastAlert"
        when: windowShown

        readonly property string vibrateUri: "luna://com.palm.vibrate/vibrate"
        readonly property string displayUri: "luna://com.palm.display/control/setState"

        function shortTone() {
            return Qt.resolvedUrl("data/two-seconds.wav").toString().replace("file://", "");
        }

        function init() {
            alert.pending = [];
            alert.toneOwed = false;
            alert.inCall = false;
            alert.headphones = false;
            alert.throughMute = false;
            alert._liftedOutput = "";
            masterStatus = { muted: true, soundOutput: "pcm_output" };
            muteCalls = [];
            calls = [];
            vibrations = [];
        }

        function called(uri) {
            return calls.filter(function(c) { return c === uri; }).length;
        }

        function messageItem() {
            return findChild(alert, "cellBroadcastMessage");
        }

        function test_a_short_message_sits_in_the_middle() {
            alert.show("Dreiging", "");
            var text = messageItem();
            compare(text.horizontalAlignment, Text.AlignHCenter);
            var middle = text.mapToItem(alert, 0, text.height / 2).y;
            verify(Math.abs(middle - alert.height / 2) < alert.height / 8,
                   "middle at " + middle + " of " + alert.height);
        }

        function test_a_long_message_stays_on_screen_and_scrolls() {
            var longText = "";
            for (var i = 0; i < 400; i++)
                longText += "Dreiging in uw omgeving. ";
            alert.show(longText, "");
            wait(0);
            var area = findChild(alert, "cellBroadcastMessageArea");
            verify(area.contentHeight > area.height);
            var title = area.mapToItem(alert, 0, 0).y;
            verify(title > 0, "message from " + title);
            var ok = findChild(alert, "cellBroadcastOk");
            var foot = ok.mapToItem(alert, 0, ok.height).y;
            verify(foot < alert.height, "OK ends at " + foot + " of " + alert.height);
        }

        function test_a_short_message_is_a_dialog_not_the_whole_screen() {
            alert.show("Dreiging", "");
            var ok = findChild(alert, "cellBroadcastOk");
            tryVerify(function() {
                return ok.mapToItem(alert, 0, ok.height).y < alert.height * 0.75;
            }, 1000, "OK ends at " + ok.mapToItem(alert, 0, ok.height).y);
        }

        function test_OK_acknowledges() {
            alert.show("Dreiging", "");
            findChild(alert, "cellBroadcastOk").clicked();
            verify(!alert.visible);
        }

        function test_the_text_is_larger_than_a_dialogs() {
            verify(messageItem().font.pixelSize > FontUtils.sizeToPixels("medium"));
            verify(alert.titleSize > alert.messageSize);
        }

        function test_it_carries_the_legacy_warning_triangle() {
            alert.show("Dreiging", "");
            tryCompare(findChild(alert, "cellBroadcastIcon"), "status", Image.Ready);
        }

        function test_the_title_is_red() {
            var title = findChild(alert, "cellBroadcastTitle");
            compare(title.text, "Emergency Alert");
            compare(title.color, "#be0003");
        }

        function test_text_is_never_markup() {
            compare(messageItem().textFormat, Text.PlainText);
        }

        function test_hidden_with_nothing_to_show() {
            verify(!alert.visible);
        }

        function test_shows_until_acknowledged() {
            alert.show("Dreiging", shortTone());
            verify(alert.visible);
            compare(alert.currentText, "Dreiging");
            alert.acknowledge();
            verify(!alert.visible);
        }

        function test_the_tone_is_asked_for() {
            alert.show("Dreiging", shortTone());
            verify(alert.toneWanted);
        }

        function test_no_tone_without_a_file() {
            alert.show("Dreiging", "");
            verify(!alert.toneOwed);
            verify(alert.visible);
        }

        function test_acknowledging_stops_the_tone() {
            alert.show("Dreiging", shortTone());
            alert.acknowledge();
            verify(!alert.toneWanted);
        }

        function test_vibrates_and_wakes() {
            alert.show("Dreiging", "");
            compare(called(vibrateUri), 1);
            compare(called(displayUri), 1);
            alert.acknowledge();
        }

        function test_vibrates_long_short_short() {
            alert.show("Dreiging", "");
            wait(3000);
            compare(vibrations.length, 2);
            tryVerify(function() { return vibrations.length === 3; }, 2000);
            compare(vibrations, [2000, 1000, 1000]);
        }

        function test_acknowledging_ends_the_vibration() {
            alert.show("Dreiging", "");
            alert.acknowledge();
            wait(3000);
            compare(vibrations, [2000]);
        }

        function test_during_a_call_vibrates_only() {
            alert.inCall = true;
            alert.show("Dreiging", shortTone());
            compare(called(vibrateUri), 1);
            compare(called(displayUri), 0);
            verify(alert.visible);
            verify(!alert.toneWanted);
        }

        function test_a_call_starting_stops_the_tone() {
            alert.show("Dreiging", shortTone());
            verify(alert.toneWanted);
            alert.inCall = true;
            verify(!alert.toneWanted);
        }

        function test_tone_and_screen_after_the_call() {
            alert.inCall = true;
            alert.show("Dreiging", shortTone());
            alert.inCall = false;
            verify(alert.toneWanted);
            compare(called(displayUri), 1);
        }

        function test_nothing_after_the_call_once_acknowledged() {
            alert.inCall = true;
            alert.show("Dreiging", shortTone());
            alert.acknowledge();
            alert.inCall = false;
            verify(!alert.toneWanted);
            compare(called(displayUri), 0);
        }

        function test_two_languages_wait_their_turn() {
            alert.show("Dreiging", shortTone());
            alert.show("Threat", shortTone());
            compare(alert.currentText, "Dreiging");
            alert.acknowledge();
            verify(alert.visible);
            compare(alert.currentText, "Threat");
            verify(alert.toneOwed);
            alert.acknowledge();
            verify(!alert.visible);
            verify(!alert.toneOwed);
        }

        /* The player itself, not only what is asked of it. */
        function test_the_player_starts_and_is_stopped_by_a_call() {
            var player = findChild(alert, "cellBroadcastTone");
            alert.show("Dreiging", shortTone());
            tryCompare(player, "playbackState", MediaPlayer.PlayingState);
            alert.inCall = true;
            tryCompare(player, "playbackState", MediaPlayer.StoppedState);
            alert.inCall = false;
            tryCompare(player, "playbackState", MediaPlayer.PlayingState);
            alert.acknowledge();
            tryCompare(player, "playbackState", MediaPlayer.StoppedState);
        }

        function test_the_tone_plays_once() {
            var player = findChild(alert, "cellBroadcastTone");
            alert.show("Dreiging", shortTone());
            tryCompare(player, "playbackState", MediaPlayer.PlayingState);
            tryVerify(function() { return !alert.toneOwed; }, 5000);
            verify(alert.visible);
            compare(player.playbackState, MediaPlayer.StoppedState);
        }

        function test_a_later_warning_sounds_again() {
            var player = findChild(alert, "cellBroadcastTone");
            alert.show("Dreiging", shortTone());
            tryVerify(function() { return !alert.toneOwed; }, 5000);
            alert.show("Threat", shortTone());
            tryCompare(player, "playbackState", MediaPlayer.PlayingState);
        }

        function test_a_mute_stays_without_the_override() {
            alert.show("one", shortTone(), false);
            compare(muteCalls, []);
        }

        function test_the_override_lifts_the_mute_and_puts_it_back() {
            alert.show("one", shortTone(), true);
            compare(muteCalls, ["pcm_output:false"]);
            alert.acknowledge();
            compare(muteCalls, ["pcm_output:false", "pcm_output:true"]);
            verify(!alert.throughMute);
        }

        function test_the_override_leaves_an_unmuted_phone_alone() {
            masterStatus = { muted: false, soundOutput: "pcm_output" };
            alert.show("one", shortTone(), true);
            alert.acknowledge();
            compare(muteCalls, []);
        }

        function test_the_override_waits_for_a_call_to_end() {
            alert.inCall = true;
            alert.show("one", shortTone(), true);
            compare(muteCalls, []);
            alert.inCall = false;
            compare(muteCalls, ["pcm_output:false"]);
            alert.inCall = true;
            compare(muteCalls, ["pcm_output:false", "pcm_output:true"]);
        }

        function test_no_volume_status_leaves_the_mute() {
            masterStatus = null;
            alert.show("one", shortTone(), true);
            alert.acknowledge();
            compare(muteCalls, []);
        }

        function test_markup_in_a_message_stays_text() {
            alert.show("<b>x</b>", "");
            var message = findChild(alert, "cellBroadcastMessage");
            compare(message.textFormat, Text.PlainText);
        }

        function test_quiet_on_headphones() {
            var output = findChild(alert, "cellBroadcastOutput");
            compare(output.volume, 1.0);
            alert.headphones = true;
            compare(output.volume, 0.125);
        }

        function test_a_tap_outside_the_button_does_not_dismiss() {
            alert.show("Dreiging", "");
            mouseClick(alert, 10, 10);
            verify(alert.visible);
        }
    }
}
