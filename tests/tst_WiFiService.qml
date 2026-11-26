/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import QtTest 1.2

import "../qml/Connectors"
import "../qml/Connectors/WifiSignal.js" as WifiSignal
import "../qml/StatusBar/SystemMenu"

/*
 * The status bar's Wi-Fi bars. They follow the connected service's strength,
 * and find that service from the list itself: the technology's Connected can
 * arrive before the list is filled in (libconnman-qt emits it first), and
 * Connman's stand-in never sets it at all, so bars that waited for it stayed
 * at zero while the system menu showed the network.
 */
TestCase {
    id: testCase
    name: "WiFiService"

    Component {
        id: entryComponent
        WifiEntry { width: 400; height: 40 }
    }

    Component {
        id: serviceComponent
        WiFiService { }
    }

    function technologyModel(service) {
        for (var i = 0; i < service.resources.length; i++) {
            var r = service.resources[i];
            if (r.hasOwnProperty("_wifiServices"))
                return r;
        }
        return null;
    }

    function test_barsWithoutConnectedChange() {
        var service = createTemporaryObject(serviceComponent, testCase);
        verify(technologyModel(service).connected === false);
        // "My Own Wifi": online, strength 90.
        compare(service.signalBars, 3);
        verify(service.online);
    }

    function test_followsStrength() {
        var service = createTemporaryObject(serviceComponent, testCase);
        var wifi = technologyModel(service)._wifiServices[0];
        wifi.strength = 40;
        compare(service.signalBars, 2);
        wifi.strength = 10;
        compare(service.signalBars, 1);
    }

    function test_followsServiceState() {
        var service = createTemporaryObject(serviceComponent, testCase);
        var services = technologyModel(service)._wifiServices;

        services[0].state = "idle";
        compare(service.signalBars, 0);
        verify(!service.online);

        // Connecting elsewhere: "Someone else's wifi", strength 30.
        services[1].state = "ready";
        compare(service.signalBars, 1);
        verify(!service.online);
        services[1].state = "online";
        verify(service.online);
    }

    function test_poweredOff() {
        var service = createTemporaryObject(serviceComponent, testCase);
        technologyModel(service).powered = false;
        compare(service.signalBars, 0);
        technologyModel(service).powered = true;
        compare(service.signalBars, 3);
    }

    function test_scale_data() {
        return [
            { tag: "none", strength: 0, bars: 0 },
            { tag: "weakest", strength: 1, bars: 1 },
            { tag: "below 2", strength: 33, bars: 1 },
            { tag: "2", strength: 34, bars: 2 },
            { tag: "below 3", strength: 49, bars: 2 },
            { tag: "3", strength: 50, bars: 3 },
            { tag: "full", strength: 100, bars: 3 }
        ];
    }

    function test_scale(data) {
        compare(WifiSignal.bars(data.strength), data.bars);
    }

    // The menu's row draws the same number of bars as the status bar.
    function test_menuMatchesStatusBar() {
        var service = createTemporaryObject(serviceComponent, testCase);
        var wifi = technologyModel(service)._wifiServices[0];
        var entry = createTemporaryObject(entryComponent, testCase);
        var strengths = [10, 40, 60, 100];
        for (var i = 0; i < strengths.length; i++) {
            wifi.strength = strengths[i];
            entry.strength = strengths[i];
            compare(entry._signalBars, service.signalBars, "strength " + strengths[i]);
        }
    }
}
