import QtQuick 2.0
import "globalVars.js" as NotificationsVars

QtObject {
    property int __nextId: 0

    function notify(appName, replacesId, appIcon, summary, body, actions, hints, expireTimeout) {
        __nextId++;
        NotificationsVars.__listModel.append({
                           notificationId: __nextId,
                           object: {
                               appName: appName,
                               appIcon: appIcon,
                               summary: summary,
                               body: body,
                               timestamp: "12-04-2014"
                           }
                       });
        return __nextId;
    }

    function getById(id) {
        return { appName: "org.webosports.app.settings 1456", summary: "Test Notification", body: "Body of Test notifiation", appIcon: "" };
    }

    function closeById(id, reason) {
    }
}
