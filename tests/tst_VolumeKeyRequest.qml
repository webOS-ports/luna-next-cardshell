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
}
