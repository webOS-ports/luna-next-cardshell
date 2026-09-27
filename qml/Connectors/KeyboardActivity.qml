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
import LuneOS.Service 1.0
import WebOSCoreCompositor 1.0

/*!
 * \brief Tells the display manager that someone is typing.
 *
 * Only touch and the power key reach luna-displaymanager as input: it reads them
 * from nyx, whose key set is a fixed handful of custom keys with no room for
 * ordinary keyboard ones. So on a device with a physical keyboard the screen
 * dimmed and blanked mid-sentence, because as far as the display manager was
 * concerned nothing had happened since the last time the glass was touched.
 *
 * The compositor sees every key before it is routed anywhere - a key going to an
 * application's text field never reaches the shell's own Keys handlers - and
 * WebOSKeyFilter hands each one to the filters registered here. That makes this
 * the one place in the shell that can see typing at all.
 */
Item {
    id: keyboardActivity

    //! How long to leave it before saying so again. The display manager only
    //! needs to know that activity happened; its inactivity timeout is minutes,
    //! so one call a few seconds apart is plenty and a call per keystroke would
    //! be a bus message per keystroke.
    property int reportIntervalMs: 5000

    //! What WebOSKeyPolicy::NextPolicy is worth. The enum is not registered for
    //! QML, so it has to be the number: anything else here would decide the fate
    //! of every key in the system, and this filter is only watching.
    readonly property int nextPolicy: 2

    property double _lastReported: -1
    property bool _warned: false

    LunaService {
        id: displayService
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: keyboardActivity._install()
    }

    function _install() {
        if (!compositor) {
            console.warn("KeyboardActivity: no compositor, typing will not keep the screen awake");
            return;
        }

        // A KeyFilter of our own rather than reusing whatever is there:
        // setKeyFilter() installs it on the windows and extensions that already
        // exist, so this works whenever it runs.
        if (!compositor.keyFilter)
            compositor.keyFilter = activityFilter;

        compositor.keyFilter.addKeyFilter(keyboardActivity._onKey, "displayActivity");
    }

    KeyFilter {
        id: activityFilter
    }

    function _onKey(keycode, pressed, autoRepeat, nativeModifiers) {
        // Presses only. A release adds nothing, and an auto-repeat means a key is
        // being held rather than the user doing something new.
        if (pressed && !autoRepeat)
            keyboardActivity.reportActivity();

        return keyboardActivity.nextPolicy;
    }

    //! \brief Reports activity, no more often than reportIntervalMs.
    function reportActivity() {
        var now = Date.now();

        if (_lastReported >= 0 && (now - _lastReported) < reportIntervalMs)
            return;

        _lastReported = now;

        displayService.call("luna://com.palm.display/control/notifyUserActivity", "{}",
                            keyboardActivity._onResponse, keyboardActivity._onError);
    }

    //! A rejected call comes back here with returnValue false rather than through
    //! the error callback, so it has to be checked or a refusal is silent. That
    //! is not hypothetical: this was denied by LS2 for an hour while looking
    //! like it worked, because nothing read the reply.
    function _onResponse(message) {
        var response = JSON.parse(message.payload);

        if (response.returnValue !== true)
            keyboardActivity._complain(message.payload);
    }

    function _onError(message) {
        keyboardActivity._complain(message.payload);
    }

    //! Said once: if the method or the permission is missing, every keystroke
    //! would otherwise print.
    function _complain(payload) {
        if (!keyboardActivity._warned) {
            keyboardActivity._warned = true;
            console.warn("KeyboardActivity: cannot report activity: " + payload);
        }
    }
}
