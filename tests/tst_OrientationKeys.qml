import QtQuick 2.0
import QtTest 1.0

import "../qml"

/*
 * F6-F9 turn the screen by hand (OrientationHelper.setOrientation). That
 * used to assign orientationAngle, which replaced its binding to the sensor:
 * after one key the screen never followed the phone again until the shell
 * restarted. A key's angle now holds only until the phone is turned.
 */
TestCase {
    name: "OrientationKeys"

    Item {
        id: screen
        width: 400
        height: 800

        OrientationHelper { id: helper }
    }

    // The helper's DeviceOrientation, which has no id outside the helper.
    function sensor() {
        for (var i = 0; i < helper.data.length; ++i) {
            var child = helper.data[i];
            if (child && typeof child.sample === "function" && child.settleInterval !== undefined)
                return child;
        }
        return null;
    }

    // Accelerometer samples (m/s^2, Qt's axes) for each way up.
    function hold(angle) {
        var g = 9.80665;
        var s = sensor();
        if (angle === 0) s.sample(0, g, 0);
        else if (angle === 90) s.sample(-g, 0, 0);
        else if (angle === 180) s.sample(0, -g, 0);
        else s.sample(g, 0, 0);
        tryCompare(s, "angle", angle);
    }

    function init() {
        verify(sensor() !== null, "OrientationHelper has a DeviceOrientation");
        // A turn and back, which also clears a key's angle from the test
        // before: that lasts until the phone is turned.
        hold(90);
        hold(0);
        helper.setLocked(false);
        tryCompare(helper, "orientationAngle", 0);
    }

    function test_follows_the_sensor() {
        hold(90);
        tryCompare(helper, "orientationAngle", 90);
        hold(0);
        tryCompare(helper, "orientationAngle", 0);
    }

    function test_a_key_turns_the_screen() {
        helper.setOrientation(270);
        compare(helper.orientationAngle, 270);
    }

    function test_the_sensor_still_turns_it_after_a_key() {
        helper.setOrientation(270);
        compare(helper.orientationAngle, 270);
        hold(90);
        tryCompare(helper, "orientationAngle", 90);
        hold(0);
        tryCompare(helper, "orientationAngle", 0);
    }

    function test_a_key_back_to_where_the_phone_is() {
        // F6 (upright) while the phone is upright, then a real turn.
        helper.setOrientation(0);
        compare(helper.orientationAngle, 0);
        hold(270);
        tryCompare(helper, "orientationAngle", 270);
        hold(0);
        tryCompare(helper, "orientationAngle", 0);
    }

    function test_a_key_does_nothing_while_locked() {
        helper.setLocked(true);
        helper.setOrientation(90);
        compare(helper.orientationAngle, 0);
        helper.setLocked(false);
        compare(helper.orientationAngle, 0);
    }
}
