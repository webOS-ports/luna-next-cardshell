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
import QtTest 1.0

import "../qml/StatusBar"
import "../qml/StatusBar/Indicators"
import "../qml/Connectors"

/*
 * When the status bar shows the network type (3G, 4G, 5G ...) next to the
 * signal bars: as webOS 2.2.4's luna-systemui did, only while a cellular
 * connection carries the internet, and not while Wi-Fi does.
 */
Item {
    id: root
    width: 720
    height: 40

    // What CardShell gives SystemIndicators by name
    property QtObject airplaneModeService: QtObject {
        property bool active: false
    }
    property QtObject preferences: QtObject {
        property bool rotationLock: false
        property bool rotationInvalid: false
        property int rotationLockAngle: 0
        property bool muteSound: false
    }

    TestCase {
        name: "WanTechnologyShown"
        when: windowShown

        Component {
            id: indicatorsComponent
            SystemIndicators { height: 40 }
        }

        function findAll(item, pred, out) {
            out = out || [];
            if (pred(item))
                out.push(item);
            var kids = item.children || [];
            for (var i = 0; i < kids.length; i++)
                findAll(kids[i], pred, out);
            var res = item.resources || [];
            for (var j = 0; j < res.length; j++)
                findAll(res[j], pred, out);
            return out;
        }

        function one(item, pred, what) {
            var found = findAll(item, pred);
            compare(found.length, 1, what);
            return found[0];
        }

        // com.palm.wan/getstatus, as telephonyd's src/wanservice.c words it
        function wanStatus(connectstatus, services, extra) {
            var status = {
                "returnValue": true, "simId": 0, "state": "enable", "roamguard": "enable",
                "networktype": "lte", "dataaccess": "usable", "networkstatus": "attached",
                "wanstate": "enable", "disablewan": "off", "connectedservices": []
            };
            if (connectstatus)
                status.connectedservices.push({ "service": services || ["internet"], "cid": 1,
                                                "connectstatus": connectstatus, "ipaddress": "10.0.0.2",
                                                "requeststatus": "", "errorCode": 0,
                                                "causeCode": 0, "mipFailureCode": 0 });
            for (var key in extra)
                status[key] = extra[key];
            return status;
        }

        // com.palm.connectionmanager/getStatus
        function cmStatus(wifiState, wifiOnInternet) {
            return { "returnValue": true, "isInternetConnectionAvailable": true,
                     "cellular": { "enabled": true },
                     "wan": { "onInternet": false, "connected": false },
                     "wifi": { "state": wifiState, "onInternet": wifiOnInternet } };
        }

        function makeBar() {
            var bar = createTemporaryObject(indicatorsComponent, root);
            verify(bar !== null, "SystemIndicators did not load");
            var t = {
                bar: bar,
                telephony: one(bar, function(i) {
                    return i.hasOwnProperty("volte") && i.hasOwnProperty("registration");
                }, "the telephony connector"),
                wan: one(bar, function(i) {
                    return i.hasOwnProperty("roamGuard") && i.hasOwnProperty("technology");
                }, "the WAN connector"),
                indicator: one(bar, function(i) {
                    return i.hasOwnProperty("technology") && i.hasOwnProperty("imageSource");
                }, "the network type indicator")
            };
            t.getstatus = one(t.wan, function(i) { return i.method === "getstatus"; },
                              "the com.palm.wan subscription");
            t.cm = one(t.wan, function(i) { return i.method === "getStatus"; },
                       "the connection manager subscription");
            t.telephony.powered = true;
            return t;
        }

        function answer(service, reply) {
            service.onResponse({ "payload": JSON.stringify(reply) });
        }

        function test_shown_with_mobile_data_on() {
            var t = makeBar();
            answer(t.cm, cmStatus("disconnected", "no"));
            answer(t.getstatus, wanStatus("active"));
            verify(t.wan.internetConnected);
            tryVerify(function() { return t.indicator.visible; }, 2000, "4G with mobile data on");
            compare(t.indicator.technology, "lte");
        }

        function test_hidden_with_mobile_data_off() {
            var t = makeBar();
            answer(t.cm, cmStatus("disconnected", "no"));
            // registered on 5G, but no data connection: what the Radon reported
            answer(t.getstatus, wanStatus(null, null, { "networktype": "5g" }));
            compare(t.wan.technology, "5g");
            verify(!t.wan.internetConnected);
            verify(!t.indicator.visible, "no 5G without a data connection");

            answer(t.getstatus, wanStatus("disconnected", null, { "networktype": "5g" }));
            verify(!t.indicator.visible, "nor with the context down");
            answer(t.getstatus, wanStatus("connecting", null, { "networktype": "5g" }));
            verify(!t.indicator.visible, "nor while it comes up");

            answer(t.getstatus, wanStatus("active", null, { "networktype": "5g" }));
            tryVerify(function() { return t.indicator.visible; }, 2000, "5G once it is up");

            answer(t.getstatus, wanStatus(null, null, { "networktype": "5g" }));
            tryVerify(function() { return !t.indicator.visible; }, 2000, "gone with mobile data off again");
        }

        function test_hidden_while_wifi_carries_the_internet() {
            var t = makeBar();
            answer(t.getstatus, wanStatus("active"));
            answer(t.cm, cmStatus("connected", "yes"));
            verify(t.wan.wifiOnInternet);
            verify(!t.indicator.visible, "Wi-Fi carries the internet");

            // Wi-Fi without internet (a captive portal, say) leaves cellular shown
            answer(t.cm, cmStatus("connected", "no"));
            verify(!t.wan.wifiOnInternet);
            tryVerify(function() { return t.indicator.visible; }, 2000, "Wi-Fi without internet");

            answer(t.cm, cmStatus("connected", "yes"));
            tryVerify(function() { return !t.indicator.visible; }, 2000, "Wi-Fi on the internet again");
            answer(t.cm, cmStatus("disconnected", "no"));
            tryVerify(function() { return t.indicator.visible; }, 2000, "Wi-Fi gone");

            // only a connected Wi-Fi counts, as on 2.2.4
            answer(t.cm, cmStatus("disconnected", "yes"));
            verify(!t.wan.wifiOnInternet);

            // a connection manager that cannot answer does not hide it
            answer(t.cm, cmStatus("connected", "yes"));
            answer(t.cm, { "returnValue": false });
            verify(!t.wan.wifiOnInternet);
        }

        function test_dormant_counts_as_up() {
            var t = makeBar();
            answer(t.getstatus, wanStatus("dormant", null, { "networktype": "evdo" }));
            tryVerify(function() { return t.indicator.visible; }, 2000);
        }

        function test_only_the_internet_context() {
            var t = makeBar();
            // MMS alone is no data connection
            answer(t.getstatus, wanStatus("active", ["mms"]));
            verify(!t.wan.internetConnected);
            // the one context for internet and MMS together is
            answer(t.getstatus, wanStatus("active", ["internet", "mms"]));
            verify(t.wan.internetConnected);
        }

        function test_data_access_and_attach_must_hold() {
            var t = makeBar();
            answer(t.getstatus, wanStatus("active", null, { "dataaccess": "unusable" }));
            verify(!t.wan.internetConnected, "data access unusable");
            answer(t.getstatus, wanStatus("active", null, { "networkstatus": "notattached" }));
            verify(!t.wan.internetConnected, "not attached");
            answer(t.getstatus, wanStatus("active"));
            verify(t.wan.internetConnected);
        }

        function test_cleared_when_the_status_fails() {
            var t = makeBar();
            answer(t.getstatus, wanStatus("active"));
            verify(t.wan.internetConnected);
            // the reply acknowledging a subscribe carries no status: it changes nothing
            answer(t.getstatus, { "returnValue": true, "subscribed": true });
            verify(t.wan.internetConnected);
            answer(t.getstatus, { "returnValue": false });
            verify(!t.wan.internetConnected);
            tryVerify(function() { return !t.indicator.visible; }, 2000);
        }

        // telephonyd (com.palm.wan) or the connection manager goes off the bus
        function test_cleared_when_a_service_goes() {
            var t = makeBar();
            var wanBus = one(t.wan, function(i) { return i.serviceName === "com.palm.wan"; },
                             "the com.palm.wan watch");
            var cmBus = one(t.wan, function(i) { return i.serviceName === "com.palm.connectionmanager"; },
                            "the connection manager watch");
            answer(t.getstatus, wanStatus("active"));
            answer(t.cm, cmStatus("connected", "yes"));
            verify(t.wan.internetConnected);
            verify(t.wan.wifiOnInternet);

            cmBus._available = true;
            cmBus._available = false;
            verify(!t.wan.wifiOnInternet, "connection manager gone");

            wanBus._available = true;
            wanBus._available = false;
            verify(!t.wan.internetConnected, "com.palm.wan gone");
        }

        function test_hidden_with_the_modem_off_or_in_airplane_mode() {
            var t = makeBar();
            answer(t.getstatus, wanStatus("active"));
            tryVerify(function() { return t.indicator.visible; }, 2000);
            t.telephony.powered = false;
            tryVerify(function() { return !t.indicator.visible; }, 2000, "modem off");
            t.telephony.powered = true;
            root.airplaneModeService.active = true;
            tryVerify(function() { return !t.indicator.visible; }, 2000, "airplane mode");
            root.airplaneModeService.active = false;
            tryVerify(function() { return t.indicator.visible; }, 2000);
        }
    }
}
