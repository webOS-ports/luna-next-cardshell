import QtQuick 2.0
import LunaNext.Common 0.1
import LuneOS.Service 1.0

import "../LunaSysAPI" as LunaSysAPI

ListModel {
    id: tabAppsModel

    property ListModel appsModel: LunaSysAPI.ApplicationModel {
        Component.onCompleted: appsModel.appsModelRefreshed.connect(refreshConfig);
    }
    property string launcherTab
    property bool isDefaultTab: false

    Component.onCompleted: {
        // Read the default tab configuation file
        var xhr = new XMLHttpRequest;
        if( !Settings.isTestEnvironment ) {
            xhr.open("GET", Qt.resolvedUrl("/etc/palm/default-launcher-page-layout.json"));
        }
        else {
            xhr.open("GET", Qt.resolvedUrl("../Tests/default-launcher-page-layout.json"));
        }
        xhr.onreadystatechange = function() {
            if( xhr.readyState === XMLHttpRequest.DONE ) {
                var fullDefaultConfig = JSON.parse(xhr.responseText);
                _defaultTabConfig = [];

                var iItem;
                for( var iTab in fullDefaultConfig ) {
                    if( fullDefaultConfig[iTab].title === launcherTab.toLowerCase() ) {
                        for( iItem in fullDefaultConfig[iTab].items ) {
                            _defaultTabConfig.push( fullDefaultConfig[iTab].items[iItem] );
                        }
                    }
                    else {
                        for( iItem in fullDefaultConfig[iTab].items ) {
                            _defaultTabExclConfig.push( fullDefaultConfig[iTab].items[iItem] );
                        }
                    }
                }
                refreshConfig();
            }
        }
        xhr.send();
        // Read the db8 configuration: the db schema the following:
        //   appId: string
        //   tab: string
        //   pos: int
        if( !Settings.isTestEnvironment ) {
            __queryDB("find",
                      {query:{from:"org.webosports.lunalaunchertab:1",
                              where: [ {prop:"tab",op:"=",val:launcherTab} ],
                              orderBy: "pos", desc: false}},
                      __launchTabDBResult);
        }
    }

    function __launchTabDBResult(message) {
        var result = JSON.parse(message.payload);
        _dbTabConfig = [];

        if( result && result.results && result.results.length ) {
            for( var i=0; i<result.results.length; ++i ) {
                var obj = result.results[i];
                _dbTabConfig.push( obj.appId );
            }
        }

        refreshConfig();
    }

    property var _defaultTabConfig: []
    property var _defaultTabExclConfig: []
    property var _dbTabConfig: []

    // refreshes the tab configuration
    function refreshConfig() {
        // for all the apps from appsModel, apply the default configuration,
        // and overload it with the one coming from db8.
        // If it is not yet referenced in db8 nor in default, then include it only if we are
        // the default tab
        tabAppsModel.clear();
        var nbApps = appsModel.count;
        for( var i = 0; i < nbApps; ++i ) {
            var appObj = appsModel.get(i);
            var posInTab = _dbTabConfig.indexOf(appObj.id);
            if( posInTab < 0 ) {
                posInTab = _defaultTabConfig.indexOf(appObj.id + "_default");
            }
            if( posInTab >= 0 || (isDefaultTab && _defaultTabExclConfig.indexOf(appObj.id + "_default")<0) ) {
                tabAppsModel.append( appObj );
            }
        }
    }

    // db8 management
    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }
    function __handleDBError(message) {
        console.log("Could not fulfill DB operation : " + message)
    }

    function __queryDB(action, params, handleResultFct) {
        lunaNextLS2Service.call("luna://com.palm.db/" + action, JSON.stringify(params),
                  handleResultFct, __handleDBError)
    }
}
