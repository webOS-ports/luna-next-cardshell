import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * The alerts in the middle of the screen share one place, as LunaSysMgr's
 * single VolumeControlAlertWindow did: the newest replaces the one showing.
 * And the volume level does not come up for audio that only moved to (or
 * away from) a headset - that is AudioOutputAlert's to show.
 */
Item {
    width: 480
    height: 800

    VolumeControlAlert { id: volumeAlert }
    AudioOutputAlert { id: outputAlert }
    KillSwitchAlert { id: switchAlert }

    CentreAlertSlot {
        alerts: [volumeAlert, outputAlert, switchAlert]
    }

    TestCase {
        name: "CentreAlertSlot"
        when: windowShown

        function volume(fields, callerId) {
            var status = { muted: false, volume: 50, soundOutput: "pcm_output", sessionId: 0 };
            for (var k in fields)
                status[k] = fields[k];
            var payload = { volumeStatus: status, returnValue: true,
                            callerId: callerId === undefined ? "com.webos.surfacemanager-cardshell"
                                                             : callerId };
            volumeAlert.onAudioStatusChanged({ payload: JSON.stringify(payload) });
        }

        function init() {
            volumeAlert.dismiss();
            outputAlert.dismiss();
            switchAlert.dismiss();
            volumeAlert._hadFirstAudioStatus = false;
            volumeAlert._lastSoundOutput = "";
            /* The subscription's first reply: how things already were. */
            volume({});
        }

        function visibleCount() {
            return (volumeAlert.visible ? 1 : 0) + (outputAlert.visible ? 1 : 0) +
                   (switchAlert.visible ? 1 : 0);
        }

        function test_first_status_shows_nothing() {
            verify(!volumeAlert.visible);
        }

        function test_volume_change_shows_the_level() {
            volume({ volume: 60 });
            verify(volumeAlert.visible);
        }

        function test_headset_then_volume_key_replaces() {
            outputAlert.showOutput("wired", true);
            verify(outputAlert.visible);
            volume({ volume: 60 });
            verify(volumeAlert.visible);
            verify(!outputAlert.visible);
            compare(visibleCount(), 1);
        }

        function test_volume_then_headset_replaces() {
            volume({ volume: 60 });
            outputAlert.showOutput("bluetooth", true);
            verify(outputAlert.visible);
            verify(!volumeAlert.visible);
            compare(visibleCount(), 1);
        }

        function test_switch_replaces_and_is_replaced() {
            volume({ muted: true });
            switchAlert.showSwitch("microphone", "blocked");
            verify(switchAlert.visible);
            verify(!volumeAlert.visible);
            outputAlert.showOutput("wired", false);
            verify(!switchAlert.visible);
            compare(visibleCount(), 1);
        }

        function test_replaced_alert_stays_down() {
            volume({ volume: 60 });
            outputAlert.showOutput("wired", true);
            /* The volume alert's own timer must not bring it back, nor
             * leave it running to cut the next one short. */
            wait(100);
            verify(!volumeAlert.visible);
            verify(outputAlert.visible);
        }

        /* audiod restoring the stored volume of an output that connects. */
        function test_internal_restore_is_routing() {
            volume({ volume: 30 }, "internal");
            verify(!volumeAlert.visible);
        }

        /* The status naming another output: the route changed. */
        function test_output_change_is_routing() {
            volume({ volume: 30, soundOutput: "bluetooth_speaker0" });
            verify(!volumeAlert.visible);
            /* The next key press on that output shows again. */
            volume({ volume: 40, soundOutput: "bluetooth_speaker0" });
            verify(volumeAlert.visible);
        }

        function test_plug_with_restore_shows_only_headphones() {
            outputAlert.showOutput("wired", true);
            volume({ volume: 30 }, "internal");
            verify(outputAlert.visible);
            verify(!volumeAlert.visible);
        }

        function test_volume_alert_restarts_its_time() {
            volume({ volume: 60 });
            wait(1500);
            volume({ volume: 70 });
            wait(1000);
            /* 2.5 s after the first press, 1 s after the second. */
            verify(volumeAlert.visible);
        }
    }
}
