import QtQuick 2.0
import LunaNext.Common 0.1

import "LauncherTabs.js" as LauncherTabs
import "../LunaSysAPI" as LunaSysAPI

ListModel {
    id: tabAppsModel

    property ListModel appsModel: LunaSysAPI.ApplicationModel {
        Component.onCompleted: appsModel.appsModelRefreshed.connect(refreshConfig);
    }

    // The placements the user made themselves, shared by all tabs. A ListModel
    // cannot hold a Connections, so it is the launcher that calls refreshConfig()
    // whenever this changes.
    property LauncherTabConfig tabConfig

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
    }

    property var _defaultTabConfig: []
    property var _defaultTabExclConfig: []

    // refreshes the tab configuration
    function refreshConfig() {
        // For every app of appsModel, decide whether it belongs on this tab.
        // A placement the user made themselves wins, then the tab rules of
        // LauncherTabs.js, then the default configuration file. What none of
        // them mentions ends up on the default tab.
        tabAppsModel.clear();
        var unsortedAppsArray = [];
        var nbApps = appsModel.count;
        // everything the configuration does not order goes after the default elements
        var unorderedPos = nbApps + _defaultTabConfig.length + 1;
        for( var i = 0; i < nbApps; ++i ) {
            var appObj = appsModel.get(i);
            var posInTab = -1;
            var placement = !!tabConfig ? tabConfig.placementOf(appObj.id) : undefined;

            if( placement !== undefined ) {
                // the user dragged that app somewhere: honour it, wherever that is
                if( placement.tab === launcherTab ) posInTab = placement.pos;
            }
            else {
                var ruleTab = LauncherTabs.tabForApp(appObj.id);
                if( ruleTab.length > 0 ) {
                    if( ruleTab === launcherTab ) posInTab = unorderedPos;
                }
                else {
                    var posInDefaultTab = _defaultTabConfig.indexOf(appObj.id + "_default");
                    if( posInDefaultTab >= 0 ) {
                        // put it at the end of the list
                        posInTab = nbApps + posInDefaultTab;
                    }
                    else if( isDefaultTab && _defaultTabExclConfig.indexOf(appObj.id + "_default")<0 ) {
                        // put it at the very end of the list, after default elements
                        posInTab = unorderedPos;
                    }
                }
            }

            if( posInTab >= 0 ) {
                unsortedAppsArray.push( {pos: posInTab, appObj: appObj} );
            }
        }
        // sort the positions, and what shares the same position by title
        unsortedAppsArray.sort(function(a,b){
            if( a.pos !== b.pos ) return a.pos - b.pos;
            return String(a.appObj.title).localeCompare(String(b.appObj.title));
        });
        // fill the model
        for( var j = 0; j < unsortedAppsArray.length; ++j ) {
            tabAppsModel.append(unsortedAppsArray[j].appObj);
        }
    }
}
