import QtQuick 2.0

import "WindowTypeStub.js" as WindowType

ListModel {
    id: windowModel

    property int windowTypeFilter: 0;

    property variant connects: Connections {
        target: compositor
        onWindowAddedInListModel: {
            if( window.windowType === windowTypeFilter ) {
                windowModel.append({"window": window});
                console.log("Window of type " + windowTypeFilter + " has been added to a WindowModel.");
            }
        }
        onWindowRemovedFromListModel: {
            if( window.windowType === windowTypeFilter ) {
                windowModel.removeValue(window);
            }
        }
    }

    function removeValue(window) {
        var i=0;
        for(i=0; i<windowModel.count;i++) {
            if(get(i).window === window) {
                windowModel.remove(i);
                console.log("Window of type " + windowTypeFilter + " has been removed from a WindowModel.");
                break;
            }
        }
    }

    function getByIndex(i) {
        return get(i).window;
    }

    Component.onCompleted: console.log("WindowModel for type " + windowTypeFilter + " created.");
}
