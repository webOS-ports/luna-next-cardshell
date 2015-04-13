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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

ListModel {
    id: applicationModel

    // filter as a JSON list of property filters
    // For example, to select only the app "org.webosports.calc", the
    // filter should be :  { title: 'org.webosports.calc' }
    property var filter
    // when the includeAppsWithMissingProperty flag is true and one of the filtering
    // properties is not found on the launchPoint object, the result
    property bool includeAppsWithMissingProperty: false

    // signal sent whenever the list of apps has been updated
    signal appsModelRefreshed();

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

    function isFilteredOut(launchPoint) {
        if( !applicationModel.filter ) return false; // no filter

        for( var key in applicationModel.filter ) {
            // if the filtering property isn't there or if it doesn't correspond to the filter,
            // then filter that launchPoint out
            if( !applicationModel.includeAppsWithMissingProperty && !launchPoint.hasOwnProperty(key) ) return true;
            if( launchPoint.hasOwnProperty(key) && launchPoint[key] !== applicationModel.filter[key] ) return true;
        }

        return false;
    }

    function fillFromJSONResult(message) {
        var result = JSON.parse(message.payload);
        applicationModel.clear();
        if(result.returnValue && result.launchPoints !== undefined) {
            for(var i=0; i<result.launchPoints.length; i++) {
                if( !isFilteredOut(result.launchPoints[i]) )
                    applicationModel.append(result.launchPoints[i]);
            }
        }

        appsModelRefreshed();
    }

    function handleLaunchPointChanges(message) {
        var response = JSON.parse(message.payload);

        // skip the initial subscription confirmation
        if (response.subscribed !== undefined)
            return;

        refresh();
    }

    function handleApplicationManagerStatusChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.connected)
            return;

        // register handler for possible launch point change events
        service.subscribe("luna://com.palm.applicationManager/launchPointChanges",
            JSON.stringify({"subscribe":true}), handleLaunchPointChanges, handleError);

        refresh();
    }

    function handleError(message) {
        console.log("Failed to call application manager: " + message);
    }

    Component.onCompleted: {
        service.subscribe("luna://com.palm.bus/signal/registerServerStatus",
            JSON.stringify({"serviceName":"com.palm.applicationManager"}),
            handleApplicationManagerStatusChanged, handleError);
    }
}
