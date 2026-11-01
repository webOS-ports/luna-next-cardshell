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
import Nemo.DBus 2.0

import "CellBroadcast.js" as CellBroadcast

/*
 * Public warnings: NL-Alert, EU-Alert, CMAS, ETWS.
 *
 * ofono hands a broadcast to voicecall-manager, which owns the channel
 * catalog and re-sends it on the session bus with what to do about it. This
 * listens there rather than to ofono, so that a warning follows the same rules
 * as the Emergency Broadcast settings page, and so that triggerTestBroadcast,
 * which needs no network, reaches the screen like a real one.
 */
Item {
    id: cellBroadcastService

    /* How long the same message on the same topic stays a repeat. */
    property int repeatWindowMs: 24 * 60 * 60 * 1000

    /* soundFile is empty for a warning that does not get the tone. */
    signal warningReceived(string text, string soundFile)

    property var _seen: ({})

    function handleBroadcast(modemPath, text, properties) {
        if (!CellBroadcast.isPublicWarning(properties))
            return;
        if (CellBroadcast.isRepeat(_seen, properties.Topic, text, Date.now(), repeatWindowMs))
            return;
        console.log("CellBroadcastService: warning on " + modemPath + " topic " + properties.Topic);
        warningReceived(text, CellBroadcast.attentionSoundFile(properties));
    }

    DBusInterface {
        bus: DBus.SessionBus
        service: "org.nemomobile.voicecall"
        path: "/cellbroadcast"
        iface: "org.nemomobile.voicecall.CellBroadcast"
        signalsEnabled: true

        function broadcastReceived(modemPath, text, properties) {
            cellBroadcastService.handleBroadcast(modemPath, text, properties);
        }
    }
}
