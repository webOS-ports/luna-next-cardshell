import QtQuick 2.0
import LunaNext 0.1

Item {
    id: launchBarDisplay

    signal toggleLauncherDisplay

    height: windowManager.computeFromLength(80);

    LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    // background of quick laucnh
    Rectangle {
        anchors.fill: launchBarDisplay
        opacity: 0.2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "white" }
        }
    }

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

    ListView {
        id: launcherRow

        anchors.fill: launchBarDisplay
        orientation: ListView.Horizontal

        model: launcherListModel
        delegate: Item {
            width: launchBarDisplay.width/(launcherListModel.count+1)
            height: launchBarDisplay.height

            LaunchableAppIcon {
                id: launcherIcon

                appIcon: model.icon
                appId: model.appId

                anchors.centerIn: parent
                height: parent.height
                width: parent.width
            }
        }

        footer: Item {
            width: launchBarDisplay.width/(launcherListModel.count+1)
            height: launchBarDisplay.height

            Image {
                id: appsIcon
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                height: parent.height
                source: "../images/empty-launcher.png"

                MouseArea {
                    anchors.fill: parent
                    onClicked: launchBarDisplay.toggleLauncherDisplay()
                }
            }
        }
    }
}
