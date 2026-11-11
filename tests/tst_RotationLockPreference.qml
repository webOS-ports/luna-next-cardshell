import QtQuick 2.0
import QtTest 1.0
import LuneOS.System 1.0

import "../qml/LunaSysAPI"

/*
 * The rotationLock preference is the locked angle, or 400 when the screen
 * turns freely. Anything else in the store is no lock: an int property took
 * a false as 0, and the shell stayed upright.
 */
TestCase {
    name: "RotationLockPreference"
    when: writer.loaded

    Preferences { id: preferences }

    SystemPreferences { id: writer; keys: ["rotationLock"] }

    function store(value) {
        verify(writer.set("rotationLock", value));
    }

    function cleanup() {
        store(400);
        tryCompare(preferences, "rotationLock", false);
    }

    function test_an_angle_locks() {
        store(90);
        tryCompare(preferences, "rotationLockAngle", 90);
        compare(preferences.rotationLock, true);
        store(0);
        tryCompare(preferences, "rotationLockAngle", 0);
        compare(preferences.rotationLock, true, "upright is a lock too");
    }

    function test_free_is_no_lock() {
        store(90);
        tryCompare(preferences, "rotationLock", true);
        store(400);
        tryCompare(preferences, "rotationLock", false);
        compare(preferences.rotationLockAngle, preferences.rotationInvalid);
    }

    function test_not_a_number_is_no_lock() {
        store(90);
        tryCompare(preferences, "rotationLock", true);
        store(false);
        tryCompare(preferences, "rotationLock", false);
        compare(preferences.rotationLockAngle, preferences.rotationInvalid);
        compare(writer.value("rotationLock"), false, "what is stored is left alone");
    }
}
