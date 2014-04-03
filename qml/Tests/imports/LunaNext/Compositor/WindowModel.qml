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
                break;
            }
        }
    }

    function getByIndex(i) {
        if( i>=count ) {
            console.log("index out of range !");
        }

        return get(i).window;
    }
}
