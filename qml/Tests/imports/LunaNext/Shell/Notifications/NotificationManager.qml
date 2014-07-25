import QtQuick 2.0
import "globalVars.js" as NotificationsVars

QtObject {
    property int __nextId: 0

    function notify(appName, replacesId, appIcon, summary, body, actions, hints, expireTimeout) {
        __nextId++;
        NotificationsVars.__listModel.append({
                           object: {
                               appName: appName,
                               appIcon: appIcon,
                               summary: summary,
                               body: body,
                               timestamp: "12-04-2014",
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
