import QtQuick 2.0

QtObject {
    function notify(appName, replacesId, appIcon, summary, body, actions, hints, expireTimeout) {
    }

    function getById(id) {
        return { appName: "org.webosports.app.settings 1456", summary: "Test Notification", body: "Body of Test notifiation", appIcon: "" };
    }

    function closeById(id, reason) {
    }
}
