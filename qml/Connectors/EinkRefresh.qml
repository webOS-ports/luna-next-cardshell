/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.5
import QtQuick.Window 2.2
import LuneOS.Service 1.0

/*
 * The shell's side of org.webosports.service.eink, the E Ink refresh-mode
 * service (Minimal Phone MP01). Two jobs:
 *
 *  - mirror the service's status (available, mode, modes) for whoever shows
 *    it - the refresh menu - and relay its refresh key: a long press arrives
 *    here as menuRequested().
 *
 *  - decide when the screen is "moving" for the service's auto mode. The
 *    shell lives in the compositor process, so every frame the compositor
 *    renders passes through this window's frameSwapped - client surfaces
 *    included. A burst of frames means something is scrolling or animating
 *    and the panel should be on its fast waveform; a pause means it can go
 *    back to the clean one. The thresholds are the whole policy: a status
 *    bar clock ticking once a second never reaches the burst count, and the
 *    idle time is stock Android's shortest "scroll ended" return delay.
 *
 * Inert on any device without the service: nothing answers, available stays
 * false and no frame is ever counted.
 */
Item {
    id: eink

    property bool available: false
    property string mode: ""
    // [{id, label, description}], in the service's order
    property var modes: []

    // Frames within burstWindow ms that count as "moving"; ms without a frame
    // that count as "still".
    //
    // Auto's pair, 1 and 4, hands over silently in both directions (measured
    // on the MP01: only entering waveform 2 flashes, which is why auto does
    // not rest there), so the thresholds are about not wasting trips rather
    // than about flashes: a keystroke or a 100 ms card animation must not
    // start one. Six frames in a quarter second is sustained motion. One
    // second without a frame is the return: the panel redraws what the fast
    // waveform drew once, properly, on the way back - unavoidable - but at
    // half a second the scroll indicator's fade-out (~0.45-0.65 s after the
    // last movement) landed after the switch and was drawn with the slow
    // waveform, a second, avoidable flash. Longer felt sluggish.
    property int burstFrames: 6
    property int burstWindow: 250
    property int idleTime: 1000

    // What the service was last told.
    property bool active: false

    signal menuRequested()

    property int _frames: 0

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
    }

    ServiceStatus {
        serviceName: "org.webosports.service.eink"

        onConnected: {
            service.subscribe("luna://org.webosports.service.eink/getStatus",
                              JSON.stringify({"subscribe": true}),
                              function(message) {
                                  var response = JSON.parse(message.payload);
                                  if (response.hasOwnProperty("modes"))
                                      eink.modes = response.modes;
                                  if (response.hasOwnProperty("mode"))
                                      eink.mode = response.mode;
                                  if (response.hasOwnProperty("available"))
                                      eink.available = response.available;
                                  // The service settles the panel itself on a
                                  // full refresh (the key, or the menu); follow
                                  // it, so the pending return is not a second
                                  // flash and the next scroll starts a new trip.
                                  if (response.active === false && eink.active) {
                                      eink.active = false;
                                      idle.stop();
                                      burst.stop();
                                  }
                              },
                              function(error) {
                                  eink.available = false;
                              });

            service.subscribe("luna://org.webosports.service.eink/watchKey",
                              JSON.stringify({"subscribe": true}),
                              function(message) {
                                  var response = JSON.parse(message.payload);
                                  if (response.event === "longPress")
                                      eink.menuRequested();
                              },
                              function(error) { });

            // A fresh service starts out "still"; make sure our notion matches.
            eink.active = false;
        }

        onDisconnected: {
            eink.available = false;
            eink.active = false;
        }
    }

    function setMode(id) {
        service.call("luna://org.webosports.service.eink/setMode",
                     JSON.stringify({"mode": id}),
                     function(message) { },
                     function(error) { console.log("E Ink setMode failed: " + error); });
    }

    function refresh() {
        service.call("luna://org.webosports.service.eink/refresh", "{}",
                     function(message) { },
                     function(error) { console.log("E Ink refresh failed: " + error); });
    }

    /* ---- screen activity, for the service's auto mode ---- */

    Connections {
        target: eink.Window.window
        enabled: eink.available && eink.mode === "auto"
        function onFrameSwapped() { eink._frame(); }
    }

    // Counts frames for burstWindow ms, then starts over.
    Timer {
        id: burst
        interval: eink.burstWindow
        onTriggered: eink._frames = 0
    }

    Timer {
        id: idle
        interval: eink.idleTime
        onTriggered: eink._setActive(false)
    }

    function _frame() {
        idle.restart();

        if (active)
            return;

        if (!burst.running) {
            _frames = 0;
            burst.start();
        }

        if (++_frames >= burstFrames)
            _setActive(true);
    }

    onModeChanged: {
        // Leaving auto: whatever we said last no longer matters to the
        // service, but the next entry into auto must start clean.
        if (mode !== "auto") {
            idle.stop();
            burst.stop();
            if (active)
                _setActive(false);
        }
    }

    function _setActive(on) {
        if (active === on)
            return;

        active = on;
        service.call("luna://org.webosports.service.eink/setActive",
                     JSON.stringify({"active": on}),
                     function(message) { },
                     function(error) { console.log("E Ink setActive failed: " + error); });
    }
}
