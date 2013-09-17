import QtQuick 2.0

// The notification area can take three states:
//  - closed: nothing is shown
//  - minimized: only notification icons are shown
//  - open: all notifications with their content are shown

// Todo: 1. see if there is another way to resize the list when an element is
//          added. This highly dynamic sizing is slow.
//       2. don't use a listview, because it is flickable and uselessly dynamic.

Rectangle {
    id: dashboard

    property Item windowManagerInstance

    height: 0

    color: "black"
    state: "closed"

    ListModel {
        id: notificationsModel
    }

    function addNotification(notif) {
        var icon = "../images/generic-notification.png";
        if(notif.icon) icon = notif.icon;
        var content = "New notification";
        if(notif.content) content = notif.content;

        notificationsModel.append({"icon": icon, "htmlContent":content});

        if( dashboard.state === "closed" )
            dashboard.state = "minimized";
    }

    ListView {
        id: minimizedListView

        x: 0; y: 0; width: parent.width
        height: notificationsModel.count > 0 ? windowManager.computeFromLength(32) : 0;
        interactive: false

        orientation: ListView.Horizontal
        layoutDirection: Qt.RightToLeft
        model: notificationsModel

        delegate: Item {
            width: parent.height
            height: parent.height

            Image {
                id: notifIconImage
                source: model.icon
                anchors.fill: parent
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                windowManagerInstance.dashboardMode();
            }
        }
    }

    ListView {
        id: openListView

        x: 0; y: 0; width: parent.width
        height: 0;
        interactive: false

        orientation: ListView.Vertical
        model: notificationsModel

        delegate: Row {
                id: fullNotificationRow
                Image {
                    anchors.verticalCenter: fullNotificationRow.verticalCenter
                    source: model.icon
                    width: windowManager.computeFromLength(30);
                    height: windowManager.computeFromLength(30);
                }
                Text {
                    anchors.verticalCenter: fullNotificationRow.verticalCenter
                    color: "white"
                    text: model.htmlContent
                }

                Component.onCompleted: openListView.height += fullNotificationRow.height;
                Component.onDestruction: openListView.height -= fullNotificationRow.height;
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                windowManagerInstance.cardViewMode();
            }
        }
    }

    Behavior on height {
        NumberAnimation { duration: 150 }
    }

    states: [
        State {
            name: "closed"
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: dashboard; height: 0 }
        },
        State {
            name: "minimized"
            PropertyChanges { target: minimizedListView; visible: true }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: dashboard; height: minimizedListView.height }
        },
        State {
            name: "open"
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: true }
            PropertyChanges { target: dashboard; height: openListView.height }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "open";
        }
        onSwitchToMaximize: {
            state = "minimized";
        }
        onSwitchToFullscreen: {
            state = "closed";
        }
        onSwitchToCardView: {
            state = "minimized";
        }
        onExpandLauncher: {
            state = "minimized";
        }
    }
}
