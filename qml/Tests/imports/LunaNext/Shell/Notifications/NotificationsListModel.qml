import QtQuick 2.0
import "globalVars.js" as NotificationsVars

ListModel {
    id: notificationModel

    property int itemCount: count
    signal itemAdded(variant object);

    onRowsInserted: itemAdded(notificationModel.get(last).object);

    Component.onCompleted: {
        NotificationsVars.__listModel = notificationModel;
    }
}
