import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * Which hardware keys the shell acts on. Back, HomePage and Menu are also the
 * keycodes of an Android phone's capacitive keys, so their default actions
 * apply only while navigationKeysEnabled; an action a device's
 * /etc/luneos/hardware-keys.json gives one of them applies regardless. The
 * override file is the JSON luneos-device-config writes for the Q25 from
 * deviceinfo_key_actions.
 *
 * Keys are fed to _onKey(), the function HardwareKeys registers with the
 * compositor's key filter. Only releases are sent where a press would need the
 * compositor's seat ("shell.back") or telephony ("call.hangup").
 */
TestCase {
    name: "HardwareKeys"

    Component {
        id: hardwareKeysComponent
        HardwareKeys {}
    }

    SignalSpy {
        id: launcherSpy
        signalName: "launcherToggleRequested"
    }

    function pathOf(file) {
        return decodeURIComponent(Qt.resolvedUrl(file).toString().replace(/^file:\/\//, ""));
    }

    function createKeys(overrideFile, navigationKeysEnabled) {
        const keys = createTemporaryObject(hardwareKeysComponent, null, {
            overridePath: overrideFile ? pathOf(overrideFile) : "/nonexistent/hardware-keys.json",
            navigationKeysEnabled: navigationKeysEnabled
        });
        launcherSpy.target = keys;
        launcherSpy.clear();
        return keys;
    }

    function press(keys, keycode) {
        const onPress = keys._onKey(keycode, true, false, 0);
        const onRelease = keys._onKey(keycode, false, false, 0);
        compare(onRelease, onPress, "press and release decided alike");
        return onPress;
    }

    function release(keys, keycode) {
        return keys._onKey(keycode, false, false, 0);
    }

    function test_navigationKeysOff_data() {
        return [
            { tag: "Key_Back", key: Qt.Key_Back },
            { tag: "Key_HomePage", key: Qt.Key_HomePage },
            { tag: "Key_Menu", key: Qt.Key_Menu }
        ];
    }

    function test_navigationKeysOff(data) {
        const keys = createKeys("", false);
        compare(keys.actionFor(data.key), "none");
        compare(press(keys, data.key), keys.resultNextPolicy);
        compare(launcherSpy.count, 0);
    }

    function test_navigationKeysOn() {
        const keys = createKeys("", true);

        compare(press(keys, Qt.Key_HomePage), keys.resultAccepted);
        compare(launcherSpy.count, 1);
        compare(press(keys, Qt.Key_Menu), keys.resultAccepted);
        compare(launcherSpy.count, 2);

        compare(keys.actionFor(Qt.Key_Back), "shell.back");
        compare(release(keys, Qt.Key_Back), keys.resultAccepted);
    }

    function test_switchingTakesEffectAtOnce() {
        const keys = createKeys("", false);
        compare(press(keys, Qt.Key_HomePage), keys.resultNextPolicy);

        keys.navigationKeysEnabled = true;
        compare(press(keys, Qt.Key_HomePage), keys.resultAccepted);
        compare(launcherSpy.count, 1);
    }

    function test_callKeysIgnoreTheSwitch() {
        const keys = createKeys("", false);
        compare(keys.actionFor(Qt.Key_Call), "call.answer");
        compare(keys.actionFor(Qt.Key_Hangup), "call.hangup");
        compare(keys.actionFor(Qt.Key_VolumeMute), "audio.mute");
    }

    function test_deviceOverrideIgnoresTheSwitch() {
        const keys = createKeys("data/hardware-keys-q25.json", false);

        compare(keys.actionFor(Qt.Key_HomePage), "call.hangup");
        compare(release(keys, Qt.Key_HomePage), keys.resultAccepted);

        // Not named by the override, so still a default and still off.
        compare(keys.actionFor(Qt.Key_Back), "none");
        compare(press(keys, Qt.Key_Back), keys.resultNextPolicy);
    }

    SignalSpy {
        id: mediaSpy
        signalName: "mediaKeySent"
    }

    function mediaKeys(inCall) {
        const keys = createKeys("", false);
        keys.inCall = inCall;
        mediaSpy.target = keys;
        mediaSpy.clear();
        return keys;
    }

    function sent() {
        var out = [];
        for (var i = 0; i < mediaSpy.count; ++i)
            out.push(mediaSpy.signalArguments[i][0]);
        return out.join(",");
    }

    function test_mediaKeysGoToMediacontroller_data() {
        return [
            { tag: "Key_MediaPlay", key: Qt.Key_MediaPlay, keyEvent: "play" },
            { tag: "Key_MediaPause", key: Qt.Key_MediaPause, keyEvent: "pause" },
            { tag: "Key_MediaStop", key: Qt.Key_MediaStop, keyEvent: "stop" },
            { tag: "Key_MediaNext", key: Qt.Key_MediaNext, keyEvent: "next" },
            { tag: "Key_MediaPrevious", key: Qt.Key_MediaPrevious, keyEvent: "previous" }
        ];
    }

    function test_mediaKeysGoToMediacontroller(data) {
        const keys = mediaKeys(false);
        compare(press(keys, data.key), keys.resultAccepted, "not handed to the focused window too");
        compare(sent(), data.keyEvent, "sent once, on the press");
    }

    function test_theHeadsetButtonIsCounted() {
        const keys = mediaKeys(false);
        compare(press(keys, Qt.Key_MediaTogglePlayPause), keys.resultAccepted);
        compare(sent(), "", "waits for a second press");
        tryCompare(mediaSpy, "count", 1, 2000);
        compare(sent(), "playPause");

        mediaSpy.clear();
        press(keys, Qt.Key_MediaTogglePlayPause);
        press(keys, Qt.Key_MediaTogglePlayPause);
        tryCompare(mediaSpy, "count", 1, 2000);
        wait(600);
        compare(sent(), "next", "two presses: the next track and nothing else");

        mediaSpy.clear();
        press(keys, Qt.Key_MediaTogglePlayPause);
        press(keys, Qt.Key_MediaTogglePlayPause);
        press(keys, Qt.Key_MediaTogglePlayPause);
        compare(sent(), "previous", "three: the previous one, at once");
    }

    function test_anAutoRepeatIsNotAnotherPress() {
        const keys = mediaKeys(false);
        keys._onKey(Qt.Key_MediaNext, true, false, 0);
        compare(keys._onKey(Qt.Key_MediaNext, true, true, 0), keys.resultAccepted);
        keys._onKey(Qt.Key_MediaNext, false, false, 0);
        compare(sent(), "next");
    }

    function test_inACallMediaKeysAreLeftAlone() {
        const keys = mediaKeys(true);
        compare(press(keys, Qt.Key_MediaPlay), keys.resultNextPolicy);
        compare(press(keys, Qt.Key_MediaNext), keys.resultNextPolicy);
        wait(600);
        compare(mediaSpy.count, 0, "nothing may start the music under a call");
    }

    function test_inACallTheHeadsetButtonIsTheCalls() {
        // mediacontroller gives it to the Phone app: a press answers or hangs up
        const keys = mediaKeys(true);
        compare(press(keys, Qt.Key_MediaTogglePlayPause), keys.resultAccepted,
                "handed to the focused window as well");
        tryCompare(mediaSpy, "count", 1, 2000);
        compare(sent(), "playPause");
    }

    function test_inACallAHoldIsSent() {
        // a long press rejects a ringing call
        const keys = mediaKeys(true);
        compare(keys._onKey(Qt.Key_MediaTogglePlayPause, true, false, 0), keys.resultAccepted);
        tryCompare(mediaSpy, "count", 1, 3000);
        compare(sent(), "hold");
        compare(keys._onKey(Qt.Key_MediaTogglePlayPause, false, false, 0), keys.resultAccepted);
        wait(600);
        compare(sent(), "hold", "the release after a hold is no press");
    }

    function test_aDeviceCanTurnTheHeadsetButtonOff() {
        const keys = mediaKeys(false);
        compare(keys.knownActions.indexOf("media.headset") >= 0, true);
        compare(keys.keyNames["Key_MediaTogglePlayPause"], Qt.Key_MediaTogglePlayPause);
        compare(keys.actionFor(Qt.Key_MediaTogglePlayPause), "media.headset");
    }

    function test_aHoldIsSentAsHold() {
        // mediacontroller hands it to the Phone app during a call and drops it otherwise
        const keys = mediaKeys(false);
        keys._headsetStep({ action: "hold", timerMs: 0 });
        compare(sent(), "hold");
        compare(JSON.parse(keys._mediaKeyPayload("hold")), { displayId: 0, keyEvent: "hold" });
    }

    function test_whatMediacontrollerIsSent() {
        const keys = mediaKeys(false);
        compare(JSON.parse(keys._mediaKeyPayload("next")), { displayId: 0, keyEvent: "next" });
    }
}
