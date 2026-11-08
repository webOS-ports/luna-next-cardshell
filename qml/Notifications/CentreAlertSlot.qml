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
 * The one place in the middle of the screen that the brief alerts share:
 * the volume level and muted bell, the headphones coming or going, and the
 * privacy switches. They all centre on the screen, so two at once drew one
 * on top of the other.
 *
 * LunaSysMgr had a single window for this. NativeAlertManager kept one
 * VolumeControlAlertWindow (m_win) and, when something new came in while it
 * was up, changed what it drew - setDrawType(), setVolumeLevel() - and
 * restarted its timer; the ringer switch's bell was one of those draw types,
 * not a window of its own. So the newest alert replaces the one showing,
 * and is up for its full time.
 *
 * Each alert in alerts emits shown() when it comes up and takes dismiss()
 * to go away early.
 */
QtObject {
    id: slot

    property var alerts: []

    function _take(alert) {
        for (var i = 0; i < alerts.length; i++) {
            if (alerts[i] !== alert)
                alerts[i].dismiss();
        }
    }

    function _connect(alert) {
        alert.shown.connect(function() { slot._take(alert); });
    }

    Component.onCompleted: {
        for (var i = 0; i < alerts.length; i++)
            _connect(alerts[i]);
    }
}
