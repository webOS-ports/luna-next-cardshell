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
import LunaNext.Common 0.1
import LuneOS.Service 1.0

/*
 * The launcher placements the user made themselves, shared by every tab.
 *
 * They live in db8 as org.webosports.lunalaunchertab:1 objects:
 *   appId: string
 *   tab: string
 *   pos: int
 *
 * This is read once for all tabs rather than once per tab, so a tab can tell
 * "this app was placed somewhere else" from "this app was never placed", which
 * is what keeps an app the user dragged out of a tab from coming back into it.
 */
QtObject {
    id: launcherTabConfig

    // appId -> { tab: string, pos: int }. Reassigned as a whole on every
    // change, so that bindings and onPlacementsChanged fire.
    property var placements: ({})

    function placementOf(appId) {
        return placements[appId];
    }

    /*
     * Replace the layout of the given tabs at once, and persist it.
     * layouts is an array of { tab: string, appIds: [string] }.
     *
     * All tabs are handed over in one call on purpose: saving them one by one
     * would make each save refresh the tab models, so a tab that had not saved
     * yet would rebuild itself from a half-updated configuration and lose the
     * app that was just dragged into it.
     */
    function setLayouts(layouts) {
        var newPlacements = {};
        var rewritten = {};
        var i, j;

        for (i = 0; i < layouts.length; ++i)
            rewritten[layouts[i].tab] = true;

        // keep the placements of the tabs we are not rewriting
        for (var appId in placements) {
            if (!rewritten[placements[appId].tab])
                newPlacements[appId] = placements[appId];
        }

        for (i = 0; i < layouts.length; ++i) {
            for (j = 0; j < layouts[i].appIds.length; ++j)
                newPlacements[layouts[i].appIds[j]] = { tab: layouts[i].tab, pos: j };
        }

        placements = newPlacements;

        if (!Settings.isTestEnvironment)
            __persist(layouts);
    }

    Component.onCompleted: {
        if (Settings.isTestEnvironment) return;

        __queryDB("find",
                  {query: {from: "org.webosports.lunalaunchertab:1",
                           orderBy: "pos", desc: false}},
                  __handleFindResult);
    }

    function __handleFindResult(message) {
        var result = JSON.parse(message.payload);
        var newPlacements = {};

        if (result && result.results) {
            for (var i = 0; i < result.results.length; ++i) {
                var obj = result.results[i];
                newPlacements[obj.appId] = { tab: obj.tab, pos: obj.pos };
            }
        }

        placements = newPlacements;
    }

    function __persist(layouts) {
        var objects = [];

        for (var i = 0; i < layouts.length; ++i) {
            // first, clean up what db8 still has for that tab
            __queryDB("del",
                      {query: {from: "org.webosports.lunalaunchertab:1",
                               where: [ {prop: "tab", op: "=", val: layouts[i].tab} ]}},
                      function (message) {});

            for (var j = 0; j < layouts[i].appIds.length; ++j) {
                objects.push({_kind: "org.webosports.lunalaunchertab:1",
                              pos: j,
                              tab: layouts[i].tab,
                              appId: layouts[i].appIds[j]});
            }
        }

        if (objects.length > 0)
            __queryDB("put", {objects: objects}, function (message) {});
    }

    // db8 management
    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "com.webos.surfacemanager-cardshell"
    }

    function __handleDBError(message) {
        console.log("Could not fulfill DB operation : " + message)
    }

    function __queryDB(action, params, handleResultFct) {
        lunaNextLS2Service.call("luna://com.palm.db/" + action, JSON.stringify(params),
                                handleResultFct, __handleDBError)
    }
}
