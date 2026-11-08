import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * AirplaneModePreference: an app's change to the airplaneMode preference is a
 * request; the value at start and the shell's own write are not.
 */
TestCase {
    name: "AirplaneModePreference"

    AirplaneModePreference {
        id: preference
    }

    SignalSpy {
        id: requests
        target: preference
        signalName: "requested"
    }

    function pref(fields) {
        preference.handle({ payload: JSON.stringify(fields) });
    }

    function init() {
        preference.active = false;
        preference.busy = false;
        preference._seenFirst = false;
        preference._written = undefined;
        requests.clear();
    }

    function test_value_at_start_is_no_request() {
        preference.active = true;
        pref({ airplaneMode: false });
        compare(requests.count, 0);
    }

    function test_app_turns_it_off() {
        preference.active = true;
        pref({ airplaneMode: true });
        pref({ airplaneMode: false });
        compare(requests.count, 1);
        compare(requests.signalArguments[0][0], false);
    }

    function test_app_turns_it_on() {
        pref({ airplaneMode: false });
        pref({ airplaneMode: true });
        compare(requests.count, 1);
        compare(requests.signalArguments[0][0], true);
    }

    function test_already_there_is_no_request() {
        pref({ airplaneMode: false });
        pref({ airplaneMode: false });
        compare(requests.count, 0);
    }

    function test_not_during_a_transition() {
        preference.active = true;
        pref({ airplaneMode: true });
        preference.busy = true;
        pref({ airplaneMode: false });
        compare(requests.count, 0);
    }

    // The radios did not follow the last switch: the watchdog ended it, active
    // still differs, and the shell's own write must not start it all again.
    function test_own_write_is_no_request() {
        pref({ airplaneMode: false });
        preference.noteWritten(true);
        pref({ airplaneMode: true });
        compare(requests.count, 0);
    }

    function test_other_keys_are_ignored() {
        pref({ airplaneMode: true });
        pref({ somethingElse: 1 });
        compare(requests.count, 0);
    }
}
