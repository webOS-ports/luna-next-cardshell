import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications/VolumeAlert.js" as VolumeAlert

/*
 * What the volume overlay shows: the music indicator for the master volume,
 * and the phone indicator for the call volume.
 */
TestCase {
    name: "VolumeAlert"

    function test_theBarHasNineSteps() {
        compare(VolumeAlert.level(0), 0);
        compare(VolumeAlert.level(50), 50);
        compare(VolumeAlert.level(100), 90);
        compare(VolumeAlert.level(-5), 0);
        compare(VolumeAlert.level(150), 90);
    }

    function test_everyCallVolumeLevelHasAnImage() {
        for (var v = 0; v <= 100; v += 20) {
            var image = Qt.resolvedUrl("../qml/Notifications/" + VolumeAlert.phoneImage(v));
            var item = Qt.createQmlObject('import QtQuick 2.0; Image { source: "' + image + '" }', this);
            tryCompare(item, "status", Image.Ready, 2000, "image for " + v);
            item.destroy();
        }
    }

    function test_theCallLevelsAreDistinct() {
        var seen = {};
        for (var v = 0; v <= 100; v += 20)
            seen[VolumeAlert.level(v)] = true;
        compare(Object.keys(seen).length, 6);
    }

    function test_phoneAndMusicImagesDiffer() {
        verify(VolumeAlert.phoneImage(60).indexOf("notification-phone-indicator-50.png") >= 0);
        verify(VolumeAlert.musicImage(60).indexOf("notification-music-indicator-50.png") >= 0);
    }

    function test_onlyAVolumeTheUserChangedIsShown() {
        verify(VolumeAlert.isCallVolumeChange({ action: "changed", changed: ["volume"], volume: 60 }));
        verify(!VolumeAlert.isCallVolumeChange({ action: "changed", volume: 60, inCall: true }),
               "the call starting or a route change");
        verify(!VolumeAlert.isCallVolumeChange({ changed: ["muted"], volume: 60 }));
        verify(!VolumeAlert.isCallVolumeChange({ changed: "volume", volume: 60 }));
        verify(!VolumeAlert.isCallVolumeChange({ changed: ["volume"] }));
        verify(!VolumeAlert.isCallVolumeChange(null));
    }
}
