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

/*
 * Says so in the journal when bootmgr does not get to a state the shell runs
 * in.
 *
 * The shell takes its state from bootmgr and only from "normal" or
 * "firstuse"; until one of those arrives it has none, and in that state its
 * gestures are off and a tap on the status bar indicators does not open the
 * system menu - with nothing logged. Until bootmgr answers at all, the shell
 * is not even loaded: the boot logo stays up. So the grace period runs from
 * the start, not from the first answer. "startup" on its own is normal for a
 * moment at boot and after a shell restart. It stays there when bootmgr never
 * sees the shell on the bus: luna-appmanager older than 4ff4586 waits for
 * com.webos.surfacemanager-cardshell, the shell's name before it became
 * com.webos.surfacemanager.cardshell.
 *
 * console.warn, as console.log does not reach the journal on device.
 */
Item {
    id: watchdog

    // how long bootmgr may report something else before this warns
    property int graceMs: 30000
    // the last state bootmgr reported
    readonly property string lastState: _lastState
    property string _lastState: ""

    signal stuck(string state)

    Component.onCompleted: graceTimer.start()

    function report(state) {
        _lastState = state;
        if (state === "normal" || state === "firstuse")
            graceTimer.stop();
        else if (!graceTimer.running)
            graceTimer.start();
    }

    Timer {
        id: graceTimer
        interval: watchdog.graceMs
        onTriggered: {
            var after = Math.round(watchdog.graceMs / 1000) + " s";
            if (watchdog.lastState === "")
                console.warn("BootLoader: no boot state from org.webosports.bootmgr after " + after
                             + ", so the shell is not loaded and the boot logo stays up.");
            else
                console.warn("BootLoader: bootmgr still reports \"" + watchdog.lastState + "\" after "
                             + after + ", so the shell has no state: gestures and the system menu "
                             + "stay off. If it is \"startup\", luna-appmanager probably predates "
                             + "the shell's bus name com.webos.surfacemanager.cardshell (needs "
                             + "4ff4586 or later).");
            watchdog.stuck(watchdog.lastState);
        }
    }
}
