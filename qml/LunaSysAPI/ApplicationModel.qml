/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LunaNext 0.1

ListModel {
    id: applicationModel

    property string filter: "*"
    property QtObject lunaNextLS2Service: LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    function applyFilter(newFilter) {
        filter = newFilter;
        refresh()
    }

    function refresh() {
        service.call("luna://com.palm.applicationManager/listLaunchPoints",
            "{}", fillFromJSONResult, handleError);
    }

    function fillFromJSONResult(data) {
        var result = JSON.parse(data);
        applicationModel.clear();
        if(result.returnValue && result.launchPoints !== undefined) {
            for(var i=0; i<result.launchPoints.length; i++) {
                applicationModel.append(result.launchPoints[i]);
            }
        }
    }

    function handleLaunchPointChanges(data) {
        var response = JSON.parse(data);

        // skip the initial subscription confirmation
        if (response.subscribed !== undefined)
            return;

        refresh();
    }

    function handleApplicationManagerStatusChanged(data) {
        var response = JSON.parse(data);

        if (!response.connected)
            return;

        // register handler for possible launch point change events
        service.subscribe("luna://com.palm.applicationManager/launchPointChanges",
            JSON.stringify({"subscribe":true}), handleLaunchPointChanges, handleError);

        refresh();
    }

    function handleError(errorMessage) {
        console.log("Failed to call application manager: " + errorMessage);
    }

    Component.onCompleted: {
        service.subscribe("luna://com.palm.bus/signal/registerServerStatus",
            JSON.stringify({"serviceName":"com.palm.applicationManager"}),
            handleApplicationManagerStatusChanged, handleError);
    }
}
