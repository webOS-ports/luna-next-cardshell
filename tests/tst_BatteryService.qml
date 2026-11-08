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

/**
 * Which battery levels the shell itself sounds. Only a full charge: systemui
 * announces a low battery, with a banner's tone at 20% and 10% and the 5%
 * popup's own sound, so a sound from here at those levels would be the second.
 */
TestCase {
    id: testCase
    name: "BatteryService"

    Component {
        id: serviceComponent
        BatteryService {}
    }

    // Counts the times a media player starts. It is given a file of silence:
    // the real sounds need not be on a development machine, and on one that
    // has them nothing here is to be heard.
    Component {
        id: counterComponent
        Connections {
            property int starts: 0
            // Stopped again at once: play() on a player still playing starts
            // nothing, which would hide a second sound.
            function onPlayingChanged() {
                if (target.playing) {
                    starts++;
                    target.stop();
                }
            }
        }
    }

    property var service: null
    property var counters: []

    function init() {
        service = createTemporaryObject(serviceComponent, testCase);
        // Whatever the mock batteryd answers the first query with is not this test's.
        wait(50);
        counters = players().map(function(player) {
            player.source = Qt.resolvedUrl("data/battery-silence.wav");
            return createTemporaryObject(counterComponent, testCase, { target: player });
        });
    }

    function players() {
        var found = [];
        for (var i = 0; i < service.data.length; i++) {
            if (service.data[i].mediaStatus !== undefined)
                found.push(service.data[i]);
        }
        return found;
    }

    function report(percent) {
        service.handlePowerdBatteryEvent({ payload: JSON.stringify({ percent_ui: percent }) });
    }

    function plays() {
        wait(50);
        var count = 0;
        counters.forEach(function(counter) { count += counter.starts; });
        return count;
    }

    function dischargeTo(target) {
        for (var percent = 94; percent >= target; percent--)
            report(percent);
    }

    function test_the_shell_has_no_low_battery_player() {
        var fresh = createTemporaryObject(serviceComponent, testCase);
        for (var i = 0; i < fresh.data.length; i++) {
            if (fresh.data[i].mediaStatus !== undefined)
                verify(fresh.data[i].source.toString().indexOf("battery_low") < 0);
        }
    }

    function test_silent_going_down_past_every_threshold_data() {
        return [
            { tag: "20%", level: 20 },
            { tag: "10%", level: 10 },
            { tag: "5%", level: 5 },
            { tag: "1%", level: 1 }
        ];
    }

    function test_silent_going_down_past_every_threshold(data) {
        dischargeTo(data.level);
        compare(service.percentage, data.level);
        compare(plays(), 0);
    }

    // A gauge that jumps over a threshold, and one that hovers on it.
    function test_silent_when_the_level_jumps_or_repeats() {
        report(50);
        report(4);
        report(4);
        report(5);
        report(4);
        compare(plays(), 0);
    }

    function test_a_full_charge_sounds_once() {
        report(50);
        report(100);
        compare(plays(), 1);
        report(99);
        report(100);
        compare(plays(), 1);
    }

    function test_a_full_charge_after_the_thresholds_still_sounds() {
        dischargeTo(5);
        compare(plays(), 0);
        report(100);
        compare(plays(), 1);
    }

    // Coming back from 94% or lower is a charge; topping up from 97% is not.
    function test_no_charged_sound_after_a_small_top_up() {
        report(50);
        report(100);
        compare(plays(), 1);
        report(97);
        report(100);
        compare(plays(), 1);
    }
}
