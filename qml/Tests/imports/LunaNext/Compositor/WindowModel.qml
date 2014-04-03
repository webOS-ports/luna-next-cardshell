import QtQuick 2.0

import "WindowTypeStub.js" as WindowType

ListModel {
    id: windowModel

    property int windowTypeFilter: 0;
    property ListModel _referenceModel

    property variant connectRefModel: Connections {
        target: _referenceModel
        onRowsInserted: {
            windowModel.append({"window": _referenceModel.getByIndex(last)});
        }
        onRowsAboutToBeRemoved: {
            windowModel.remove(first);
        }
    }

    property variant connectCompositor: Connections {
        target: compositor
        onWindowModelAdded: {
            if( !_referenceModel && newModel !== windowModel ) {
                if( newModel.windowTypeFilter === windowModel.windowTypeFilter )
                {
                    console.log(newModel + " becomes the reference of " + windowModel);
                    _referenceModel = newModel;
                }
            }
        }

        onWindowAddedInListModel: {
            if( !_referenceModel && window.windowType === windowTypeFilter ) {
                windowModel.append({"window": window});
            }
        }

        onWindowRemovedFromListModel: {
            if( !_referenceModel && window.windowType === windowTypeFilter ) {
                removeValue(windowModel, window);
            }
        }
    }

    function getByIndex(i) {
        if( i<0 || i>=count ) {
            console.log("index "+ i +" out of range !");
        }

        return get(i).window;
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

    Component.onCompleted: {
        compositor.addWindowModel(windowModel);
    }
}
