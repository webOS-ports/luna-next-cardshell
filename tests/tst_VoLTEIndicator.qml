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
 * The status bar says VoLTE while telephonyd reports the voice SIM registered
 * with IMS for voice (networkStatusQuery's extended.volte), and VoWiFi instead
 * while that is over Wi-Fi (extended.vowifi); and neither otherwise: not
 * without IMS voice, not from a telephonyd that does not report it, not with
 * the modem off or in airplane mode. A telephonyd that knows volte but not
 * vowifi gets VoLTE, as before.
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

    VoLTEIndicator {
        id: standalone
        height: 40
    }

    VoLTEIndicator {
        id: standaloneWifi
        height: 40
        vowifi: true
    }

    TestCase {
        name: "VoLTEIndicator"
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

        function image(indicator) {
            for (var i = 0; i < indicator.children.length; i++) {
                var c = indicator.children[i];
                if (c.hasOwnProperty("fillMode"))
                    return c;
            }
            return null;
        }

        // The connector's subscription, answered as telephonyd would
        function answerNetworkStatus(connector, reply) {
            var queries = findAll(connector, function(i) {
                return i.method === "networkStatusQuery";
            });
            compare(queries.length, 1, "the networkStatusQuery subscription");
            queries[0].onResponse({ "payload": JSON.stringify(reply) });
        }

        function registered(volte, vowifi) {
            var extended = { "state": "service", "registration": "home", "networkName": "Lebara" };
            if (volte !== undefined)
                extended.volte = volte;
            if (vowifi !== undefined)
                extended.vowifi = vowifi;
            return { "returnValue": true, "extended": extended };
        }

        function shows(indicator, name) {
            return indicator.visible
                    && indicator.imageSource.indexOf("/network-" + name + ".png") >= 0;
        }

        function makeBar() {
            var bar = createTemporaryObject(indicatorsComponent, root);
            verify(bar !== null, "SystemIndicators did not load");
            var connectors = findAll(bar, function(i) {
                return i.hasOwnProperty("volte") && i.hasOwnProperty("registration");
            });
            compare(connectors.length, 1, "the telephony connector");
            var indicators = findAll(bar, function(i) {
                return i.hasOwnProperty("imageSource") && i.hasOwnProperty("vowifi");
            });
            compare(indicators.length, 1, "the VoLTE indicator");
            return { bar: bar, telephony: connectors[0], indicator: indicators[0] };
        }

        function test_the_icon_loads() {
            verify(standalone.imageVisible);
            tryCompare(image(standalone), "status", Image.Ready, 2000);
            // As wide as "VoLTE" needs, at the height of the other network icons
            verify(image(standalone).sourceSize.width > image(standalone).sourceSize.height);
            compare(image(standalone).sourceSize.height, 72);
        }

        function test_the_vowifi_icon_loads() {
            verify(standaloneWifi.imageVisible);
            compare(standaloneWifi.imageSource.indexOf("network-vowifi.png") >= 0, true);
            tryCompare(image(standaloneWifi), "status", Image.Ready, 2000);
            tryCompare(image(standalone), "status", Image.Ready, 2000);
            // The same box as VoLTE's, as tall, wider by the extra letter
            compare(image(standaloneWifi).sourceSize.height, image(standalone).sourceSize.height);
            verify(image(standaloneWifi).sourceSize.width > image(standalone).sourceSize.width);
            verify(standaloneWifi.width > standalone.width);
        }

        function test_vowifi_follows_telephonyd() {
            var t = makeBar();
            t.telephony.powered = true;

            // Wi-Fi calling
            answerNetworkStatus(t.telephony, registered(true, true));
            verify(t.telephony.vowifi);
            verify(shows(t.indicator, "vowifi"), "VoWiFi over Wi-Fi");

            // Out of Wi-Fi coverage, onto LTE
            answerNetworkStatus(t.telephony, registered(true, false));
            verify(!t.telephony.vowifi);
            verify(shows(t.indicator, "volte"), "VoLTE after leaving Wi-Fi");

            // And back
            answerNetworkStatus(t.telephony, registered(true, true));
            verify(shows(t.indicator, "vowifi"), "VoWiFi again");

            // IMS lost
            answerNetworkStatus(t.telephony, registered(false, false));
            tryVerify(function() { return !t.indicator.visible; }, 2000, "nothing without IMS voice");
        }

        // telephonyd sets vowifi only with volte; the bar does not rely on it
        function test_vowifi_alone_still_shows() {
            var t = makeBar();
            t.telephony.powered = true;
            answerNetworkStatus(t.telephony, registered(false, true));
            verify(shows(t.indicator, "vowifi"));
        }

        function test_telephonyd_without_the_bearer_says_volte() {
            var t = makeBar();
            t.telephony.powered = true;
            answerNetworkStatus(t.telephony, registered(true, true));
            answerNetworkStatus(t.telephony, registered(true, undefined));
            verify(!t.telephony.vowifi);
            verify(shows(t.indicator, "volte"));
        }

        function test_volte_follows_telephonyd() {
            var t = makeBar();
            t.telephony.powered = true;
            verify(!t.indicator.visible, "VoLTE before telephonyd said anything");

            answerNetworkStatus(t.telephony, registered(true));
            verify(t.telephony.volte);
            verify(t.indicator.visible, "VoLTE when registered with IMS for voice");

            answerNetworkStatus(t.telephony, registered(false));
            verify(!t.telephony.volte);
            tryVerify(function() { return !t.indicator.visible; }, 2000, "no VoLTE without IMS voice");
        }

        function test_older_telephonyd_never_says_volte() {
            var t = makeBar();
            t.telephony.powered = true;
            answerNetworkStatus(t.telephony, registered(true));
            answerNetworkStatus(t.telephony, registered(undefined));
            verify(!t.telephony.volte);
        }

        function test_failed_query_clears_volte() {
            var t = makeBar();
            t.telephony.powered = true;
            answerNetworkStatus(t.telephony, registered(true, true));
            answerNetworkStatus(t.telephony, { "returnValue": false });
            verify(!t.telephony.volte);
            verify(!t.telephony.vowifi);
            tryVerify(function() { return !t.indicator.visible; }, 2000);
        }

        function test_hidden_with_the_modem_off_or_in_airplane_mode() {
            var t = makeBar();
            t.telephony.powered = true;
            answerNetworkStatus(t.telephony, registered(true));
            verify(t.indicator.visible);

            t.telephony.powered = false;
            tryVerify(function() { return !t.indicator.visible; }, 2000, "modem off");

            t.telephony.powered = true;
            tryVerify(function() { return t.indicator.visible; }, 2000, "modem back on");
            root.airplaneModeService.active = true;
            tryVerify(function() { return !t.indicator.visible; }, 2000, "airplane mode");
            root.airplaneModeService.active = false;

            answerNetworkStatus(t.telephony, registered(true, true));
            tryVerify(function() { return shows(t.indicator, "vowifi"); }, 2000);
            t.telephony.powered = false;
            tryVerify(function() { return !t.indicator.visible; }, 2000, "VoWiFi, modem off");
        }
    }
}
