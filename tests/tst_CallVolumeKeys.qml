import QtQuick 2.0
import QtTest 1.0

import "../qml/LunaSysAPI"
import "../qml/Notifications"

/*
 * The volume keys and the overlay with audiod's status: during a call the
 * keys leave the master volume alone, and the overlay shows the call volume
 * when audiod says the user changed it, and nothing when the audio only
 * moved to another output (VolumeControlAlert's isRoutingChange()).
 */
TestCase {
    name: "CallVolumeKeys"
    when: windowShown
    width: 400; height: 400

    VolumeControl { id: control }

    Item {
        width: 400; height: 400
        VolumeControlAlert { id: alert }
    }

    function phone(fields) {
        var payload = { returnValue: true, action: "changed", volume: 80, inCall: false };
        for (var k in fields)
            payload[k] = fields[k];
        return { payload: JSON.stringify(payload) };
    }

    function master(output, volume, callerId) {
        return { payload: JSON.stringify({ returnValue: true, callerId: callerId || "",
                 volumeStatus: { soundOutput: output, volume: volume, muted: false } }) };
    }

    // The overlay's image: what it shows. (Its visible is false whatever it
    // sets here, the test window not being its window.)
    function image() {
        return alert.children[1];
    }

    function shown() {
        return String(image().source);
    }

    function init() {
        control.inCall = false;
        control.currentVolume = 60;
        control.soundOutput = "pcm_output";
        alert.visible = false;
        image().source = "";
        alert._hadFirstAudioStatus = false;
        alert._lastSoundOutput = "";
    }

    function test_theKeysLeaveTheMasterVolumeAloneInACall() {
        control.handlePhoneStatus(phone({ inCall: true }));
        verify(control.inCall);
        control.handleVolumeUp();
        control.handleVolumeDown();
        control.handleVolumeDown();
        compare(control.currentVolume, 60);

        control.handlePhoneStatus(phone({ inCall: false }));
        verify(!control.inCall);
        control.handleVolumeUp();
        compare(control.currentVolume, 70);
    }

    function test_aFailedSubscriptionLeavesTheKeysOnTheMasterVolume() {
        control.handlePhoneStatus(phone({ inCall: true }));
        control.handlePhoneError({ payload: "{}" });
        verify(!control.inCall);
    }

    function test_theOverlayShowsTheCallVolume() {
        alert.onPhoneStatusChanged(phone({ inCall: true }));
        compare(shown(), "", "the call starting is not a volume change");

        alert.onPhoneStatusChanged(phone({ inCall: true, changed: ["volume"], volume: 40 }));
        verify(shown().indexOf("notification-phone-indicator-40.png") >= 0, shown());
    }

    function test_anOutputSwitchShowsNoOverlay() {
        alert.onAudioStatusChanged(master("bluetooth_speaker0", 50));
        compare(shown(), "", "the first status");
        alert.onAudioStatusChanged(master("pcm_output", 60));
        compare(shown(), "", "the headset went");
        alert.onAudioStatusChanged(master("pcm_output", 70));
        verify(shown().indexOf("notification-music-indicator-60.png") >= 0, "a key press: " + shown());
    }

    // audiod telling the shell the volume moved off a headset that went
    // (callerId "internal"): the shell follows it, the overlay stays down.
    function test_theHeadsetGoingIsFollowedWithoutAnOverlay() {
        control.handleVolumeStatus(master("bluetooth_speaker0", 50));
        alert.onAudioStatusChanged(master("bluetooth_speaker0", 50));
        control.handleVolumeStatus(master("pcm_output", 60, "internal"));
        alert.onAudioStatusChanged(master("pcm_output", 60, "internal"));
        compare(shown(), "");
        compare(control.soundOutput, "pcm_output");
        compare(control.currentVolume, 60);
        control.handleVolumeDown();
        compare(control.currentVolume, 50, "the key goes on from the phone's volume");
    }
}
