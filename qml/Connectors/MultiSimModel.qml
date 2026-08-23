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
 * The SIM slots of the device, one row per slot, as reported by
 * com.palm.telephony/simListQuery.
 *
 * Row fields: simId, present, name, iccid, imsi, msisdn, operatorName,
 * simStatus, powered, ready, bars, state, registration, networkRegistered,
 * dataRegistered, defaultForVoice, defaultForSms, defaultForData.
 */
ListModel {
    id: multiSimModel

    // number of slots the device reports, which is not the same as count while
    // a slot is known but its details have not arrived yet
    property int simCount: 0

    property int defaultVoiceSim: -1
    property int defaultSmsSim: -1
    property int defaultDataSim: -1

    // true once the device actually reports more than one slot; the UI uses
    // this to decide whether to show any SIM specific chrome at all
    readonly property bool multiSim: simCount > 1

    signal simListChanged()

    // Row index of a slot, or -1 when the slot is not in the model.
    function indexOfSim(simId) {
        for (let i = 0; i < count; i++) {
            if (get(i).simId === simId)
                return i;
        }
        return -1;
    }

    function simAt(simId) {
        var index = indexOfSim(simId);
        return index >= 0 ? get(index) : null;
    }

    // Human readable label for a slot: the user's own label when they set one,
    // otherwise the operator, falling back to the generic "SIM n".
    function labelForSim(simId) {
        var sim = simAt(simId);
        if (!sim)
            return "";
        if (sim.operatorName && sim.operatorName.length > 0 && sim.name.indexOf("SIM ") === 0)
            return sim.operatorName;
        return sim.name;
    }

    // Next slot holding a usable SIM after the given one, wrapping around.
    // Returns -1 when there is no other usable slot to move to.
    function nextPresentSim(simId) {
        if (count === 0)
            return -1;

        var start = indexOfSim(simId);
        if (start < 0)
            start = 0;

        for (let step = 1; step <= count; step++) {
            let candidate = get((start + step) % count);
            if (candidate.present && candidate.simId !== simId)
                return candidate.simId;
        }

        return -1;
    }

    function update(response) {
        var sims = response.sims || [];

        // Rewrite in place rather than clear()+append() so that delegates
        // bound to a row are not torn down and rebuilt on every update.
        for (let i = 0; i < sims.length; i++) {
            let s = sims[i];
            let entry = {
                "simId": s.simId,
                "present": !!s.present,
                "name": s.name || ("SIM " + (s.simId + 1)),
                "iccid": s.iccid || "",
                "imsi": s.imsi || "",
                "msisdn": s.msisdn || "",
                "operatorName": s.operatorName || "",
                "simStatus": s.simStatus || "simnotfound",
                "powered": !!s.powered,
                "ready": !!s.ready,
                "bars": s.bars || 0,
                "state": s.state || "noservice",
                "registration": s.registration || "noservice",
                "networkRegistered": !!s.networkRegistered,
                "dataRegistered": !!s.dataRegistered,
                "defaultForVoice": !!s.defaultForVoice,
                "defaultForSms": !!s.defaultForSms,
                "defaultForData": !!s.defaultForData
            };

            if (i < count)
                set(i, entry);
            else
                append(entry);
        }

        while (count > sims.length)
            remove(count - 1);

        simCount = response.simCount !== undefined ? response.simCount : sims.length;

        if (response.defaultSim) {
            defaultVoiceSim = response.defaultSim.voice;
            defaultSmsSim = response.defaultSim.sms;
            defaultDataSim = response.defaultSim.data;
        }

        simListChanged();
    }

    function reset() {
        clear();
        simCount = 0;
        defaultVoiceSim = -1;
        defaultSmsSim = -1;
        defaultDataSim = -1;
        simListChanged();
    }
}
