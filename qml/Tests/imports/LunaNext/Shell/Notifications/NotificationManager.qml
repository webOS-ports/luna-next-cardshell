import QtQuick 2.0
import "globalVars.js" as NotificationsVars

QtObject {
    property int __nextId: 0

    function notify(ownerId, replacesId, launchId, launchParams, title, body, iconUrl, priority, expireTimeout) {
        __nextId++;
        NotificationsVars.__listModel.append({
                           object: {
                               ownerId: ownerId,
                               launchId: launchId,
                               launchParams: launchParams,
                               title: title,
                               body: body,
                               iconUrl: iconUrl,
                               priority: priority,
                               expireTimeout: expireTimeout,
                               body: body,
                               timestamp: "2014-09-05T17:17:45.359Z", // (new Date()).toISOString(),
                               replacesId: __nextId
                           }
                       });
        return __nextId;
    }

    function getById(id) {
        for( var i = 0; i < NotificationsVars.__listModel.count; ++i ) {
            if( NotificationsVars.__listModel.get(i).object.replacesId === id ) {
                return NotificationsVars.__listModel.get(i).object
            }
        }
    }

    function closeById(id, reason) {
        for( var i = 0; i < NotificationsVars.__listModel.count; ++i ) {
            if( NotificationsVars.__listModel.get(i).object.replacesId === id ) {
                NotificationsVars.__listModel.remove(i);
                break;
            }
        }
    }

    function closeAllByAppName(appName) {
        for( var i = 0; i < NotificationsVars.__listModel.count; ++i ) {
            if( NotificationsVars.__listModel.get(i).object.appName === appName ) {
                NotificationsVars.__listModel.remove(i);
            }
        }
    }
}
