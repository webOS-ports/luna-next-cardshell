import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"
import "../qml/Connectors/CellBroadcast.js" as CellBroadcast

/*
 * Which broadcasts become a warning on screen, with or without the tone, and
 * that the network's repeats and a second modem do not start it again.
 */
TestCase {
    name: "CellBroadcastService"

    readonly property string toneFile:
        "/usr/share/cell-broadcast-provider-info/attention-tones/cellbroadcast-attention-853-960.ogg"

    /* What went to voicecall-manager, and what activeAlert answers. */
    property var voicecallCalls: []
    property var activeReply: null

    CellBroadcastService {
        id: service

        function callVoicecall(method, args, onReply, onError) {
            voicecallCalls = voicecallCalls.concat([{ method: method, args: args }]);
            if (method === "activeAlert" && onReply)
                onReply(activeReply);
        }
    }

    SignalSpy {
        id: warnings
        target: service
        signalName: "warningReceived"
    }

    function attention(topic) {
        return { Topic: topic,
                 CellBroadcastAttentionEvent: "cellbroadcast_attention",
                 CellBroadcastAttentionSoundFile: toneFile };
    }

    function init() {
        service._seen = {};
        service._records = {};
        voicecallCalls = [];
        activeReply = null;
        service.repeatWindowMs = 24 * 60 * 60 * 1000;
        warnings.clear();
    }

    function test_nl_alert_with_the_tone() {
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        compare(warnings.count, 1);
        compare(warnings.signalArguments[0][0], "Dreiging");
        compare(warnings.signalArguments[0][1], toneFile);
        compare(warnings.signalArguments[0][2], false);
    }

    function test_warning_without_the_tone_file_still_shows() {
        // The daemon leaves the attention properties off when the file is missing.
        service.handleBroadcast("/ril_0", "Dreiging", { Topic: 4370 });
        compare(warnings.count, 1);
        compare(warnings.signalArguments[0][1], "");
    }

    function test_the_real_nl_alert_channels_sound_through_a_mute() {
        service.handleBroadcast("/ril_0", "een", attention(4371));
        service.handleBroadcast("/ril_0", "twee", attention(4372));
        service.handleBroadcast("/ril_0", "drie", attention(4373));
        compare(warnings.signalArguments[0][2], true);
        compare(warnings.signalArguments[1][2], true);
        compare(warnings.signalArguments[2][2], false);
    }

    function test_range_of_warnings() {
        for (var topic of [4352, 4399]) {
            verify(CellBroadcast.isPublicWarning({ Topic: topic }), topic);
        }
        for (var other of [50, 4351, 4400]) {
            verify(!CellBroadcast.isPublicWarning({ Topic: other }), other);
        }
    }

    function test_catalog_decides_outside_the_range() {
        // Israel, Taiwan and others have warnings on low channels.
        verify(CellBroadcast.isPublicWarning(attention(919)));
    }

    function test_ordinary_broadcast_is_left_alone() {
        service.handleBroadcast("/ril_0", "Cell info", { Topic: 50 });
        compare(warnings.count, 0);
    }

    function test_etws_has_no_topic() {
        service.handleBroadcast("/ril_0", "Tsunami", { EmergencyType: "Tsunami", EmergencyAlert: true });
        compare(warnings.count, 1);
    }

    function test_nothing_is_no_warning() {
        verify(!CellBroadcast.isPublicWarning(null));
        verify(!CellBroadcast.isPublicWarning({}));
    }

    function test_second_modem_and_repeats_are_dropped() {
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        service.handleBroadcast("/ril_1", "Dreiging", attention(4370));
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        compare(warnings.count, 1);
    }

    function test_each_language_is_its_own_message() {
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        service.handleBroadcast("/ril_0", "Threat", attention(4383));
        compare(warnings.count, 2);
    }

    function test_same_text_on_another_topic_is_not_a_repeat() {
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        service.handleBroadcast("/ril_0", "Dreiging", attention(4383));
        compare(warnings.count, 2);
    }

    function test_a_new_message_on_the_same_topic_shows() {
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        service.handleBroadcast("/ril_0", "Update", attention(4370));
        compare(warnings.count, 2);
    }

    function record(id, topic, extra) {
        var properties = { RecordId: id, Topic: topic, CellBroadcastDisplay: "alert",
                           CellBroadcastTitle: "NL-Alert" };
        for (var key in extra)
            properties[key] = extra[key];
        return properties;
    }

    function acknowledged() {
        return voicecallCalls.filter(function(c) { return c.method === "acknowledgeAlert"; })
                             .map(function(c) { return c.args[0]; });
    }

    function test_voicecall_decides_what_is_shown() {
        // Classified, it is voicecall-manager's call, inside the range or not.
        service.handleBroadcast("/ril_0", "Alerta", record(1, 6400));
        service.handleBroadcast("/ril_0", "Hidden", record(2, 4370, { CellBroadcastDisplay: "none" }));
        compare(warnings.count, 1);
        compare(warnings.signalArguments[0][0], "Alerta");
    }

    function test_the_record_and_title_go_along() {
        service.handleBroadcast("/ril_0", "Dreiging", record(7, 4371));
        compare(warnings.signalArguments[0][3], 7);
        compare(warnings.signalArguments[0][4], "NL-Alert");
    }

    function test_without_a_title_the_default() {
        service.handleBroadcast("/ril_0", "Dreiging", { Topic: 4370 });
        compare(warnings.signalArguments[0][3], undefined);
        compare(warnings.signalArguments[0][4], "Emergency Alert");
    }

    function test_a_record_sent_again_is_not_shown_again() {
        // voicecall-manager sends a waiting one again once it becomes active.
        service.handleBroadcast("/ril_0", "Dreiging", record(7, 4370));
        service.handleBroadcast("/ril_0", "Threat", record(8, 4383));
        service.handleBroadcast("/ril_0", "Threat", record(8, 4383));
        compare(warnings.count, 2);
        compare(acknowledged().length, 0);
    }

    function test_a_repeat_not_shown_is_acknowledged() {
        // The second modem's copy is a record of its own; left alone it would
        // hold up voicecall-manager's queue.
        service.handleBroadcast("/ril_0", "Dreiging", record(7, 4370));
        service.handleBroadcast("/ril_1", "Dreiging", record(9, 4370));
        compare(warnings.count, 1);
        compare(acknowledged(), [{ type: "t", value: 9 }]);
    }

    function test_acknowledge_tells_voicecall() {
        service.acknowledge(12);
        service.acknowledge(undefined);
        service.acknowledge(null);
        compare(acknowledged(), [{ type: "t", value: 12 }]);
    }

    function test_the_active_alert_at_start_shows() {
        activeReply = record(5, 4370, { ModemPath: "/ril_0", Text: "Dreiging" });
        service.fetchActive();
        compare(warnings.count, 1);
        compare(warnings.signalArguments[0][0], "Dreiging");
        compare(warnings.signalArguments[0][3], 5);
        // And not again when it is sent once more.
        service.handleBroadcast("/ril_0", "Dreiging", activeReply);
        compare(warnings.count, 1);
    }

    function test_no_active_alert_at_start() {
        activeReply = {};
        service.fetchActive();
        compare(warnings.count, 0);
    }

    function test_repeat_window_ends() {
        var seen = {};
        verify(!CellBroadcast.isRepeat(seen, 4370, "a", 1000, 500));
        verify(CellBroadcast.isRepeat(seen, 4370, "a", 1499, 500));
        verify(!CellBroadcast.isRepeat(seen, 4370, "a", 1500, 500));
    }
}
