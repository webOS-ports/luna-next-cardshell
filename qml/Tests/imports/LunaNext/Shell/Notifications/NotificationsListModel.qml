import QtQuick 2.0
import "globalVars.js" as NotificationsVars

ListModel {
    id: notificationModel

    Component.onCompleted: {
        NotificationsVars.__listModel = notificationModel;

        notificationModel.append({
                                     notificationId: 1001,
                                     object: {
                                         appName: "org.webosports.tests.dummyWindow",
                                         appIcon: "",
                                         summary: "Updates are available",
                                         body: "New webOS ports update ready",
                                         timestamp: "12-04-2014"
                                     }
                                 });
        notificationModel.append({
                                     notificationId: 1002,
                                     object: {
                                         appName: "org.webosports.tests.dummyWindow",
                                         appIcon: "",
                                         summary: "You've got mail!",
                                         body: "10 new emails available",
                                         timestamp: "12-04-2014"
                                     }
                                 });
        notificationModel.append({
                                     notificationId: 1003,
                                     object: {
                                         appName: "org.webosports.tests.dummyWindow",
                                         appIcon: "",
                                         summary: "3 other notifications",
                                         body: "What's in that box?",
                                         timestamp: "12-04-2014"
                                     }
                                 });
    }
}
