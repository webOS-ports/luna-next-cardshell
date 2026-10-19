import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * The connectors follow their service's ServiceStatus, and the kill switch
 * connector lists the engaged switches from the ones the service reports.
 * The ServiceStatus mocks' availability is set by hand, as the bus would.
 */
Item {
    width: 480
    height: 800

    KillSwitchService { id: killSwitches }
    BatteryService { id: battery }

    TestCase {
        name: "ServiceAvailability"
        when: windowShown

        function serviceStatus(item) {
            for (var i = 0; i < item.data.length; i++)
                if (item.data[i].hasOwnProperty("serviceName"))
                    return item.data[i];
            return null;
        }
        function status(switches) {
            killSwitches.handleStatus({ payload: JSON.stringify({ switches: switches }) });
        }

        function init() {
            serviceStatus(killSwitches)._available = false;
            serviceStatus(battery)._available = false;
        }

        function cleanup() {
            serviceStatus(killSwitches)._available = false;
            serviceStatus(battery)._available = false;
        }

        function test_kill_switches_follow_the_service() {
            verify(!killSwitches.serviceAvailable);
            serviceStatus(killSwitches)._available = true;
            verify(killSwitches.serviceAvailable);
            serviceStatus(killSwitches)._available = false;
            verify(!killSwitches.serviceAvailable);
        }

        function test_blocked_switches_are_the_engaged_ones() {
            serviceStatus(killSwitches)._available = true;
            status([{ id: "camera", state: "blocked" }, { id: "wifi", state: "open" }]);
            compare(killSwitches.blockedSwitches.length, 1);
            compare(killSwitches.blockedSwitches[0].id, "camera");
            status([{ id: "camera", state: "blocked" }, { id: "wifi", state: "blocked" }]);
            compare(killSwitches.blockedSwitches.length, 2);
        }

        function test_no_switches_once_the_service_is_gone() {
            serviceStatus(killSwitches)._available = true;
            status([{ id: "camera", state: "blocked" }]);
            serviceStatus(killSwitches)._available = false;
            compare(killSwitches.switches.length, 0);
            compare(killSwitches.blockedSwitches.length, 0);
        }

        function test_battery_follows_batteryd() {
            verify(!battery.batterydAvailable);
            serviceStatus(battery)._available = true;
            verify(battery.batterydAvailable);
            serviceStatus(battery)._available = false;
            verify(!battery.batterydAvailable);
            compare(battery.level, -1);
        }
    }
}
