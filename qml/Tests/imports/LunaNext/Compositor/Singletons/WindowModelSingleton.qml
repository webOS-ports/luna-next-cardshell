pragma Singleton

import QtQuick 2.0

Item {
    id: windowModelSingleton

    property ListModel cardListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }
    property ListModel launcherListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }
    property ListModel overlayListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }
    property ListModel dashboardListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }
    property ListModel popupAlertListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }
    property ListModel bannerAlertListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }
    property ListModel pinListModel: ListModel {
        signal actualRowsAboutToBeRemoved(variant index, int first, int last);
        signal actualRowsInserted(variant index, int first, int last);
    }

    property Item _compositor;

    Connections {
        target: _compositor

        onWindowAddedInListModel: {
            if( window.windowType === 0 )
                windowModelSingleton.appendValue(cardListModel, {"window": window});
            else if( window.windowType === 1 )
                windowModelSingleton.appendValue(launcherListModel, {"window": window});
            else if( window.windowType === 2 )
                windowModelSingleton.appendValue(dashboardListModel, {"window": window});
            else if( window.windowType === 3 )
                windowModelSingleton.appendValue(popupAlertListModel, {"window": window});
            else if( window.windowType === 4 )
                windowModelSingleton.appendValue(bannerAlertListModel, {"window": window});
            else if( window.windowType === 5 )
                windowModelSingleton.appendValue(overlayListModel, {"window": window});
            else if( window.windowType === 6 )
                windowModelSingleton.appendValue(pinListModel, {"window": window});
        }
        onWindowRemovedFromListModel: {
            if( window.windowType === 0 )
                windowModelSingleton.removeValue(cardListModel,window);
            else if( window.windowType === 1 )
                windowModelSingleton.removeValue(launcherListModel,window);
            else if( window.windowType === 2 )
                windowModelSingleton.removeValue(dashboardListModel,window);
            else if( window.windowType === 3 )
                windowModelSingleton.removeValue(popupAlertListModel,window);
            else if( window.windowType === 4 )
                windowModelSingleton.removeValue(bannerAlertListModel,window);
            else if( window.windowType === 5 )
                windowModelSingleton.removeValue(overlayListModel,window);
            else if( window.windowType === 6 )
                windowModelSingleton.removeValue(pinListModel,window);
        }
    }

    function appendValue(model, jsonObject) {
        model.append(jsonObject);
        model.actualRowsInserted(model, model.count-1, model.count-1);
    }

    function removeValue(model, window) {
        var i=0;
        for(i=0; i<model.count;i++) {
            if(model.get(i).window === window) {
                model.actualRowsAboutToBeRemoved(model, i, i);
                model.remove(i);
                break;
            }
        }
    }

    function setCompositor(compositor) {
        _compositor = compositor;
    }
}
