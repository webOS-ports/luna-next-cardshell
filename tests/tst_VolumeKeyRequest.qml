import QtQuick 2.0
import QtTest 1.0

import "../qml/LunaSysAPI/VolumeKeyRequest.js" as VolumeKeyRequest

/*
 * What the volume keys ask audiod for: the call's volume during a call, the
 * master volume of the output in use otherwise.
 */
TestCase {
    name: "VolumeKeyRequest"

    function test_inACallTheKeysMoveTheCallVolume() {
        var up = VolumeKeyRequest.forKey(true, true, "pcm_output", 60);
        compare(up.uri, "luna://com.palm.audio/phone/offsetVolume");
        compare(JSON.stringify(up.payload), JSON.stringify({ offset: 10 }));
        compare(up.volume, -1, "the master volume is left as it is");

        var down = VolumeKeyRequest.forKey(false, true, "bluetooth_speaker0", 60);
        compare(down.uri, "luna://com.palm.audio/phone/offsetVolume");
        compare(down.payload.offset, -10);
        verify(!down.payload.hasOwnProperty("soundOutput"));
    }

    function test_outsideACallTheKeysSetTheMasterVolume() {
        var up = VolumeKeyRequest.forKey(true, false, "pcm_output", 60);
        compare(up.uri, "luna://com.webos.service.audio/master/setVolume");
        compare(up.payload.soundOutput, "pcm_output");
        compare(up.payload.volume, 70);
        compare(up.volume, 70);

        var down = VolumeKeyRequest.forKey(false, false, "bluetooth_speaker0", 50);
        compare(down.payload.soundOutput, "bluetooth_speaker0");
        compare(down.payload.volume, 40);
    }

    function test_theMasterVolumeStaysInRange() {
        compare(VolumeKeyRequest.forKey(true, false, "pcm_output", 95).payload.volume, 100);
        compare(VolumeKeyRequest.forKey(true, false, "pcm_output", 100).payload.volume, 100);
        compare(VolumeKeyRequest.forKey(false, false, "pcm_output", 5).payload.volume, 0);
        compare(VolumeKeyRequest.forKey(false, false, "pcm_output", 0).payload.volume, 0);
    }

    function test_inCallComesFromPhoneStatus() {
        verify(VolumeKeyRequest.inCallOf({ returnValue: true, inCall: true, volume: 80 }));
        verify(!VolumeKeyRequest.inCallOf({ returnValue: true, inCall: false }));
        verify(!VolumeKeyRequest.inCallOf({ returnValue: true }), "an older audiod");
        verify(!VolumeKeyRequest.inCallOf({ inCall: "true" }));
        verify(!VolumeKeyRequest.inCallOf(null));
    }

    readonly property var deviceList: ({ returnValue: true, deviceList: [
        { deviceName: "usb_mic0", type: "input", connected: false },
        { deviceName: "pcm_input", type: "input", connected: true },
        { deviceName: "pcm_output", type: "output", connected: true },
        { deviceName: "pcm_headphone", type: "output", connected: true },
        { deviceName: "bluetooth_speaker0", type: "output", connected: false }
    ] })

    function test_inputDevicesComeFromTheDeviceList() {
        compare(JSON.stringify(VolumeKeyRequest.inputDevicesOf(deviceList)),
                JSON.stringify(["usb_mic0", "pcm_input"]));
        compare(VolumeKeyRequest.inputDevicesOf({ returnValue: false }).length, 0);
        compare(VolumeKeyRequest.inputDevicesOf(null).length, 0);
    }

    // What audiod sends when it reconnects to PulseAudio: both stored volumes,
    // the input's last. The keys stayed on pcm_input and did nothing.
    function test_anInputsStatusDoesNotTakeTheKeys() {
        var inputs = VolumeKeyRequest.inputDevicesOf(deviceList);
        var out = VolumeKeyRequest.keyOutputAfterStatus("pcm_output", "pcm_output", inputs);
        out = VolumeKeyRequest.keyOutputAfterStatus(out, "pcm_input", inputs);
        compare(out, "pcm_output");
        compare(VolumeKeyRequest.forKey(true, false, out, 20).payload.soundOutput, "pcm_output");
    }

    function test_anOutputsStatusMovesTheKeysThere() {
        var inputs = VolumeKeyRequest.inputDevicesOf(deviceList);
        compare(VolumeKeyRequest.keyOutputAfterStatus("pcm_output", "bluetooth_speaker0", inputs),
                "bluetooth_speaker0");
        compare(VolumeKeyRequest.keyOutputAfterStatus("pcm_output", "", inputs), "pcm_output");
        compare(VolumeKeyRequest.keyOutputAfterStatus("pcm_output", undefined, inputs), "pcm_output");
    }

    // The statuses can come before the device list does.
    function test_anInputTakenBeforeTheListFallsBack() {
        var out = VolumeKeyRequest.keyOutputAfterStatus("pcm_output", "pcm_input", []);
        compare(out, "pcm_input", "nothing is known to be an input yet");
        var inputs = VolumeKeyRequest.inputDevicesOf(deviceList);
        compare(VolumeKeyRequest.keyOutputWithInputs(out, "pcm_output", inputs), "pcm_output");
        compare(VolumeKeyRequest.keyOutputWithInputs("bluetooth_speaker0", "pcm_output", inputs),
                "bluetooth_speaker0");
    }
}
