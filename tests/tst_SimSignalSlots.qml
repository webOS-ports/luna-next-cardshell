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
 * A SIM slot's signal bars take room in the status bar only while they show:
 * with a slot's radio off, as in airplane mode, the row closes up instead of
 * keeping an empty gap where the bars were.
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
        name: "SimSignalSlots"
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

        // simListQuery as telephonyd posts it, every slot alike
        function simList(powered, count) {
            count = count || 2;
            var sims = [];
            for (var i = 0; i < count; i++)
                sims.push({ "simId": i, "present": true, "powered": powered, "ready": true,
                            "bars": 3, "state": "service", "registration": "home" });
            return { "returnValue": true, "simCount": count, "sims": sims };
        }

        function makeBar() {
            var bar = createTemporaryObject(indicatorsComponent, root);
            verify(bar !== null, "SystemIndicators did not load");
            var connectors = findAll(bar, function(i) {
                return i.hasOwnProperty("volte") && i.hasOwnProperty("registration");
            });
            compare(connectors.length, 1, "the telephony connector");
            return { bar: bar, telephony: connectors[0] };
        }

        // The slots, each the item the Row lays out for one SIM
        function slots(bar) {
            return findAll(bar, function(i) {
                return i.toString().indexOf("TelephonySignalIndicator") === 0;
            }).map(function(i) { return i.parent; });
        }

        function test_slots_close_up_with_the_radio_off() {
            var t = makeBar();
            t.telephony.sims.update(simList(true));
            tryCompare(slots(t.bar), "length", 2);
            var s = slots(t.bar);
            tryVerify(function() { return s[0].visible && s[1].visible; }, 2000);
            tryVerify(function() { return s[0].width > 0 && s[1].width > 0; }, 2000);
            wait(500);
            var shown = t.bar.width;
            var room = s[0].width + s[1].width + 2 * t.bar.spacing;

            // Airplane mode: telephonyd reports both radios off
            t.telephony.sims.update(simList(false));
            tryVerify(function() { return !s[0].visible && !s[1].visible; }, 2000,
                      "a slot with its radio off is still laid out");
            tryCompare(t.bar, "width", shown - room, 2000);

            // And back
            t.telephony.sims.update(simList(true));
            tryVerify(function() { return s[0].visible && s[1].visible; }, 2000);
            tryCompare(t.bar, "width", shown, 2000);
        }

        // One SIM: no slot badge, the bars alone, shown and hidden the same way
        function test_one_sim_shows_and_closes_up() {
            var t = makeBar();
            t.telephony.sims.update(simList(true, 1));
            tryCompare(slots(t.bar), "length", 1);
            var s = slots(t.bar)[0];
            tryVerify(function() { return s.visible && s.width > 0; }, 2000,
                      "a single SIM's bars are not laid out");
            wait(500);
            var shown = t.bar.width;
            var room = s.width + t.bar.spacing;

            t.telephony.sims.update(simList(false, 1));
            tryCompare(s, "visible", false, 2000);
            tryCompare(t.bar, "width", shown - room, 2000);
        }
    }
}
