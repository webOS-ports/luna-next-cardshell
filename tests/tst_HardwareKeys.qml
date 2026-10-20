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
}
