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
import LuneOS.System 1.0
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

    // The bus, replaceable by the tests.
    property QtObject lunaNextLS2Service: LunaService {
        name: "com.webos.surfacemanager-cardshell"
    }

    // SAM posts a change for one launch point after another while it rescans the
    // apps - dozens for one install or removal - and every answer to listLaunchPoints
    // is the whole list, which takes the shell a while to read. So the changes of a
    // burst are answered with one list: it is asked for once they stop coming (at
    // most a second after the first), and never while the previous one is on its way.
    readonly property int refreshDelay: 150
    readonly property int refreshMaxDelay: 1000
    property double _refreshAskedAt: 0
    property bool _listing: false
    property bool _listAgain: false
    property QtObject _refreshTimer: Timer {
        interval: applicationModel.refreshDelay
        onTriggered: applicationModel._list()
    }

    function applyFilter(newFilter) {
        filter = newFilter;
        refresh()
    }

    function refresh() {
        if( !_refreshTimer.running )
            _refreshAskedAt = Date.now();
        else if( Date.now() - _refreshAskedAt >= refreshMaxDelay )
            return; // it fires soon: no more waiting for the burst to end
        _refreshTimer.restart();
    }

    function _list() {
        if( _listing ) {
            _listAgain = true;
            return;
        }
        _listing = true;
        lunaNextLS2Service.call("luna://com.webos.service.applicationManager/listLaunchPoints",
            "{}", _listed, _listFailed);
    }

    function _listed(message) {
        _listing = false;
        fillFromJSONResult(message);
        _listNext();
    }

    function _listFailed(message) {
        _listing = false;
        handleError(message);
        _listNext();
    }

    // Changes came while the list was on its way: it may be out of date already.
    function _listNext() {
        if( _listAgain ) {
            _listAgain = false;
            refresh();
        }
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
        // SAM leaves launchPoints out while it is still starting up. That is
        // not an empty list: keep what is shown until the real one comes.
        if (!result.returnValue || result.launchPoints === undefined)
            return;
        applicationModel.clear();
        if(result.returnValue && result.launchPoints !== undefined) {
            for(var i=0; i<result.launchPoints.length; i++) {
                let launchPoint = result.launchPoints[i];
                if( !isFilteredOut(launchPoint) )
                    applicationModel.append({ id: launchPoint.id,
                                              // SAM's listLaunchPoints has no appId field; the app id is in id
                                              appId: launchPoint.appId || launchPoint.id,
                                              launchPointId: launchPoint.launchPointId,
                                              title: launchPoint.title,
                                              removable: launchPoint.removable,
                                              // SAM copies appinfo.json verbatim into the launch
                                              // point, so a category set there arrives here even
                                              // though SAM itself makes no use of it
                                              category: launchPoint.category || "",
                                              icon: launchPoint.icon });
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

    // A property: a ListModel takes nothing but ListElements as children
    property QtObject applicationManagerStatus: ServiceStatus {
        serviceName: "com.webos.service.applicationmanager"
        clientName: "com.webos.surfacemanager-cardshell"
        onAvailableChanged: if (available) applicationModel.handleApplicationManagerUp()
    }

    function handleApplicationManagerUp() {
        // register handler for possible launch point change events
        lunaNextLS2Service.subscribe("luna://com.palm.applicationManager/launchPointChanges",
            JSON.stringify({"subscribe":true}), handleLaunchPointChanges, handleError);

        // SAM is on the bus before it has scanned the apps, and answers
        // without a list until then. Once it has, it posts to listLaunchPoints'
        // subscribers - without the list (SAM's postListLaunchPoints drops it),
        // so every post is taken as a cue to ask again.
        lunaNextLS2Service.subscribe("luna://com.webos.service.applicationmanager/listLaunchPoints",
            JSON.stringify({"subscribe":true}), handleLaunchPointsPosted, handleError);
    }

    function handleLaunchPointsPosted(message) {
        var response = JSON.parse(message.payload);
        if (response.launchPoints !== undefined)
            fillFromJSONResult(message);
        else
            refresh();
    }

    function handleError(message) {
        console.log("Failed to call application manager: " + message);
    }
}
