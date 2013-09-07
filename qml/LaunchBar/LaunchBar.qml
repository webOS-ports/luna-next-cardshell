import QtQuick 2.0

Item {
    id: launchBarItem

    signal startLaunchApplication(string appId)
    signal toggleLauncherDisplay

    state: "visible"
    anchors.bottom: parent.bottom

    // list of icons
    ListModel {
        id: launcherListModel

        ListElement {
            appId: "DummyWindow"
            icon: "../images/default-app-icon.png"
        }
        ListElement {
            appId: "DummyWindow"
            icon: "../images/default-app-icon.png"
        }
        ListElement {
            appId: "DummyWindow"
            icon: "../images/default-app-icon.png"
        }
        ListElement {
            appId: "DummyWindow"
            icon: "../images/default-app-icon.png"
        }
    }

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: launchBarItem; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: launchBarItem; opacity: 0 }
        },
        State {
            name: "visible"
            AnchorChanges { target: launchBarItem; anchors.top: undefined; anchors.bottom: parent.bottom }
            PropertyChanges { target: launchBarItem; opacity: 1 }
        }
    ]

    transitions: [
        Transition {
            AnchorAnimation { easing.type:Easing.InOutQuad; duration: 150 }
            NumberAnimation { property: "opacity"; duration: 150 }
        }
    ]

    // background of quick laucnh
    Rectangle {
        anchors.fill: launchBarItem
        opacity: 0.2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "white" }
        }
    }

    ListView {
        id: launcherRow

        anchors.fill: launchBarItem
        orientation: ListView.Horizontal

        model: launcherListModel
        delegate: Item {
            width: launchBarItem.width/(launcherListModel.count+1)
            height: launchBarItem.height

            LaunchableAppIcon {
                id: launcherIcon

                appIcon: model.icon
                appId: model.appId

                anchors.centerIn: parent
                height: parent.height
                width: parent.width

                onStartLaunchApplication: launchBarItem.startLaunchApplication(appId);
            }
        }

        footer: Item {
            width: launchBarItem.width/(launcherListModel.count+1)
            height: launchBarItem.height

            Image {
                id: appsIcon
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                height: parent.height
                source: "../images/empty-launcher.png"

                MouseArea {
                    anchors.fill: parent
                    onClicked: launchBarItem.toggleLauncherDisplay()
                }
            }
        }
    }
}
