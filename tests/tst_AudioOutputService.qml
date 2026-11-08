import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * AudioOutputService: what audiod's getStatus says about headphones, and
 * which changes are worth flashing an alert for. The first status after
 * (re)connecting is how things already were, so it must never flash.
 */
TestCase {
    name: "AudioOutputService"

    AudioOutputService {
        id: service
    }

    SignalSpy {
        id: changes
        target: service
        signalName: "outputChanged"
    }

    function status(fields) {
        var payload = { returnValue: true, inCall: false, speakerMode: false, micMute: false,
                        headset: false, headsetMic: false, headsetState: "unplugged",
                        bluetoothAudio: false, bluetoothAudioName: "" };
        for (var k in fields)
            payload[k] = fields[k];
        service.handleStatus({ payload: JSON.stringify(payload) });
    }

    function init() {
        service._hadFirstStatus = false;
        service.headset = false;
        service.headsetMic = false;
        service.bluetoothAudio = false;
        service.bluetoothAudioName = "";
        service.inCall = false;
        changes.clear();
    }

    function test_first_status_is_not_a_change() {
        status({ headset: true, headsetMic: true, headsetState: "headset" });
        compare(service.headset, true);
        compare(service.headsetMic, true);
        compare(changes.count, 0);
    }

    function test_plug_and_unplug() {
        status({});
        status({ headset: true, headsetState: "headphones" });
        compare(changes.count, 1);
        compare(changes.signalArguments[0][0], "wired");
        compare(changes.signalArguments[0][1], true);

        status({});
        compare(changes.count, 2);
        compare(changes.signalArguments[1][0], "wired");
        compare(changes.signalArguments[1][1], false);
        compare(service.headset, false);
    }

    function test_unchanged_status_is_quiet() {
        status({ headset: true });
        status({ headset: true, micMute: true });
        status({ headset: true, inCall: true });
        compare(changes.count, 0);
    }

    function test_bluetooth() {
        status({});
        status({ bluetoothAudio: true, bluetoothAudioName: "WH-1000XM4" });
        compare(changes.count, 1);
        compare(changes.signalArguments[0][0], "bluetooth");
        compare(changes.signalArguments[0][1], true);
        compare(service.bluetoothAudioName, "WH-1000XM4");

        status({});
        compare(changes.count, 2);
        compare(changes.signalArguments[1][1], false);
        compare(service.bluetoothAudioName, "");
    }

    function test_both_change_at_once() {
        status({});
        status({ headset: true, bluetoothAudio: true });
        compare(changes.count, 2);
    }

    function test_old_audiod_without_output_fields() {
        // An audiod that does not report headphones at all leaves everything
        // off and never counts as having sent a first status.
        service.handleStatus({ payload: JSON.stringify({ returnValue: true, inCall: false }) });
        compare(service.headset, false);
        compare(service._hadFirstStatus, false);
        compare(changes.count, 0);
    }

    function test_a_call_is_reported_and_is_not_an_output_change() {
        // HardwareKeys leaves the media keys alone while this is true.
        status({});
        compare(service.inCall, false);
        status({ inCall: true });
        compare(service.inCall, true);
        compare(changes.count, 0);
        status({ inCall: false });
        compare(service.inCall, false);
    }

    function test_audiod_going_away_ends_the_call() {
        status({ inCall: true });
        compare(service.inCall, true);
        // The bus mock reports audiod as up; take it down by hand.
        var watcher = null;
        for (var i = 0; i < service.data.length; ++i)
            if (service.data[i].serviceName === "org.webosports.service.audio")
                watcher = service.data[i];
        verify(watcher !== null, "no ServiceStatus for audiod");
        watcher._available = false;
        compare(service.serviceAvailable, false);
        compare(service.inCall, false, "the media keys would stay with the focused window");
        watcher._available = true;
    }
}
