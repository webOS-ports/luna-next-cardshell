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

    /* soundFile is empty for a warning that does not get the tone. recordId is
     * voicecall-manager's for the alert, to acknowledge it by; undefined from
     * one that keeps no record. */
    signal warningReceived(string text, string soundFile, bool throughMute,
                           var recordId, string title)

    property var _seen: ({})
    /* voicecall-manager's records handled here already. */
    property var _records: ({})

    /*
     * voicecall-manager keeps the warnings in a queue: one active, the others
     * waiting, until each is acknowledged. Until then a later one counts as
     * waiting, gets no attention request, and when the active one is
     * acknowledged it is sent again as the new active one. Hence the record
     * check here, and acknowledging a repeat that is not shown: the person
     * has the same text in front of them, or had it a moment ago, and
     * leaving it would hold up the queue.
     */
    function handleBroadcast(modemPath, text, properties) {
        var recordId = properties ? properties.RecordId : undefined;
        if (recordId !== undefined) {
            if (_records[recordId])
                return;
            _records[recordId] = true;
        }
        if (!CellBroadcast.isShown(properties))
            return;
        if (CellBroadcast.isRepeat(_seen, properties.Topic, text, Date.now(), repeatWindowMs)) {
            acknowledge(recordId);
            return;
        }
        console.log("CellBroadcastService: warning on " + modemPath + " topic " + properties.Topic);
        warningReceived(text, CellBroadcast.attentionSoundFile(properties),
                        CellBroadcast.soundsThroughMute(properties), recordId,
                        CellBroadcast.title(properties));
    }

    /* The person has read it: voicecall-manager moves on to the next one. */
    function acknowledge(recordId) {
        if (recordId === undefined || recordId === null)
            return;
        callVoicecall("acknowledgeAlert", [{ "type": "t", "value": recordId }],
                      undefined, function(error) {
            console.warn("CellBroadcastService: acknowledgeAlert " + recordId + " failed: " + error);
        });
    }

    /* A warning still up when the shell (re)starts, which no signal repeats. */
    function fetchActive() {
        callVoicecall("activeAlert", undefined, function(alert) {
            if (alert && alert.RecordId !== undefined)
                cellBroadcastService.handleBroadcast(alert.ModemPath, alert.Text, alert);
        }, function(error) {
            console.warn("CellBroadcastService: activeAlert failed: " + error);
        });
    }

    function callVoicecall(method, args, onReply, onError) {
        voicecall.typedCall(method, args, onReply, onError);
    }

    Component.onCompleted: fetchActive()

    DBusInterface {
        id: voicecall
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
