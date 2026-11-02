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
 * Tells when an app asked for airplane mode through the airplaneMode
 * preference, the way a webOS app does: legacy Phone's "Turn off Airplane
 * Mode?" popup is one call to setPreferences.
 *
 * ConnMan stays the truth for the current state. The value at start can be
 * stale, and a value the shell wrote itself is no request, so neither of those
 * switches anything.
 */
QtObject {
    /// Airplane mode as it is now.
    property bool active: false
    /// A transition is being applied.
    property bool busy: false

    signal requested(bool enabled)

    property bool _seenFirst: false
    property var _written: undefined

    /// The shell is about to store this value itself.
    function noteWritten(enabled) {
        _written = enabled;
    }

    function handle(message) {
        var wanted = JSON.parse(message.payload).airplaneMode;
        if (typeof wanted !== "boolean")
            return;

        var first = !_seenFirst;
        _seenFirst = true;

        if (first || busy || wanted === active || wanted === _written)
            return;

        requested(wanted);
    }
}
