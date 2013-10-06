import QtQuick 2.0
import QtQuick.Layouts 1.0

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

    RowLayout {
        id: launcherRow

        anchors.fill: launchBarItem
        anchors.topMargin: launchBarItem.height * 0.15
        anchors.bottomMargin: launchBarItem.height * 0.15
        spacing: 0

        Repeater {
            model: launcherListModel

            LaunchableAppIcon {
                id: launcherIcon

                Layout.fillWidth: true
                Layout.preferredHeight: launcherRow.height
                Layout.preferredWidth: launcherRow.width/(launcherListModel.count+1)

                appIcon: model.icon
                appId: model.appId

                anchors.top: parent.top
                anchors.bottom: parent.bottom

                onStartLaunchApplication: launchBarItem.startLaunchApplication(appId);
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: launcherRow.height
            Layout.preferredWidth: launcherRow.width/(launcherListModel.count+1)

            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Image {
                id: appsIcon

                anchors.fill: parent

                fillMode: Image.PreserveAspectFit
                source: "../images/empty-launcher.png"

                MouseArea {
                    anchors.fill: parent
                    onClicked: launchBarItem.toggleLauncherDisplay()
                }
            }
        }
    }
}
