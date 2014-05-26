import QtQuick 2.0

ListModel {
    id: notificationModel

    Component.onCompleted: {
        notificationModel.append({
                                     object: {
                                         appName: "org.webosports.app.email",
                                         appIcon: "",
                                         summary: "10 new emails available",
                                         body: "New webOS ports update ready",
                                         timestamp: "12-04-2014"
                                     }
                                 });
        notificationModel.append({
                                     object: {
                                         appName: "org.webosports.app.email",
                                         appIcon: "",
                                         summary: "10 new emails available",
                                         body: "New webOS ports update ready",
                                         timestamp: "12-04-2014"
                                     }
                                 });
        notificationModel.append({
                                     object: {
                                         appName: "org.webosports.app.email",
                                         appIcon: "",
                                         summary: "10 new emails available",
                                         body: "New webOS ports update ready",
                                         timestamp: "12-04-2014"
                                     }
                                 });
    }
}
