pragma Singleton

import QtQuick 2.0

Item {
    id: windowModelSingleton

    property ListModel cardListModel: ListModel { }
    property ListModel launcherListModel: ListModel { }
    property ListModel overlayListModel: ListModel { }
    property ListModel dashboardListModel: ListModel { }

    property Item _compositor;

    Connections {
        target: _compositor

        onWindowAddedInListModel: {
            if( window.windowType === 0 )
                windowModelSingleton.cardListModel.append({"window": window});
            else if( window.windowType === 1 )
                windowModelSingleton.launcherListModel.append({"window": window});
            else if( window.windowType === 2 )
                windowModelSingleton.dashboardListModel.append({"window": window});
            else if( window.windowType === 5 )
                windowModelSingleton.overlayListModel.append({"window": window});
        }
        onWindowRemovedFromListModel: {
            if( window.windowType === 0 )
                windowModelSingleton.removeValue(cardListModel,window);
            else if( window.windowType === 1 )
                windowModelSingleton.removeValue(launcherListModel,window);
            else if( window.windowType === 2 )
                windowModelSingleton.removeValue(dashboardListModel,window);
            else if( window.windowType === 5 )
                windowModelSingleton.removeValue(overlayListModel,window);
        }
    }

    function removeValue(model, window) {
        var i=0;
        for(i=0; i<model.count;i++) {
            if(model.get(i).window === window) {
                model.remove(i);
                break;
            }
        }
    }

    function setCompositor(compositor) {
        _compositor = compositor;
    }
}
