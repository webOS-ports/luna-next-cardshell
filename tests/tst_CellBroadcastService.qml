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

    CellBroadcastService {
        id: service
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
        service.repeatWindowMs = 24 * 60 * 60 * 1000;
        warnings.clear();
    }

    function test_nl_alert_with_the_tone() {
        service.handleBroadcast("/ril_0", "Dreiging", attention(4370));
        compare(warnings.count, 1);
        compare(warnings.signalArguments[0][0], "Dreiging");
        compare(warnings.signalArguments[0][1], toneFile);
    }

    function test_warning_without_the_tone_file_still_shows() {
        // The daemon leaves the attention properties off when the file is missing.
        service.handleBroadcast("/ril_0", "Dreiging", { Topic: 4370 });
        compare(warnings.count, 1);
        compare(warnings.signalArguments[0][1], "");
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

    function test_repeat_window_ends() {
        var seen = {};
        verify(!CellBroadcast.isRepeat(seen, 4370, "a", 1000, 500));
        verify(CellBroadcast.isRepeat(seen, 4370, "a", 1499, 500));
        verify(!CellBroadcast.isRepeat(seen, 4370, "a", 1500, 500));
    }
}
