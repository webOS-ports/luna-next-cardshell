import QtQuick 2.0
import "globalVars.js" as NotificationsVars

ListModel {
    id: notificationModel

    property int itemCount: count

    Component.onCompleted: {
        NotificationsVars.__listModel = notificationModel;
    }
}
