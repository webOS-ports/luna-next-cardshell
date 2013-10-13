import QtQuick 2.0
import LunaNext 0.1

/// The status bar can be divided in three main regions: app menu, title, system indicators/system menu
/// [-- app menu -- |   --- title ---    |  -- indicators --]

Rectangle {
    id: statusBarItem
    color: "black"

    property Item windowManagerInstance

    /// general title
    Item {
        id: titleItem
        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.horizontalCenter: statusBarItem.horizontalCenter

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        implicitWidth: titleText.contentWidth

        Text {
            id: titleText
            anchors.fill: parent

            horizontalAlignment: Text.AlignHCenter

            color: "white"
            font.family: Settings.fontStatusBar
            font.pointSize: 20
            fontSizeMode: Text.VerticalFit
            font.bold: true
            text: Qt.formatDateTime(new Date(), "dd.MM.yyyy")
        }
    }

    /// app menu/cellular network provider
    Loader {
        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.left: statusBarItem.left

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        Component {
            id: networkNameComponent
            Item {
                width: networkNameText.contentWidth

                Text {
                    id: networkNameText
                    anchors.fill: parent

                    horizontalAlignment: Text.AlignHCenter

                    color: "white"
                    font.family: Settings.fontStatusBar
                    font.pointSize: 20
                    fontSizeMode: Text.VerticalFit
                    font.bold: true
                    text: "myNetwork"
                }
            }
        }

        Component {
            id: appMenuComponent
            StatusBarAppMenu {
                id: appMenuItem
            }
        }

        sourceComponent: statusBarItem.state === "appSpecific" ? appMenuComponent : networkNameComponent
    }

    /// system indicators
    SystemIndicators {
        id: systemIndicatorsStatusBarItem

        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.right: statusBarItem.right

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2
    }

    state: "genericStatus"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: statusBarItem; visible: false }
        },
        State {
            name: "genericStatus"
            PropertyChanges { target: statusBarItem; visible: true }
        },
        State {
            name: "appSpecific"
            PropertyChanges { target: statusBarItem; visible: true }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "genericStatus";
        }
        onSwitchToMaximize: {
            state = "appSpecific";
        }
        onSwitchToFullscreen: {
            state = "hidden";
        }
        onSwitchToCardView: {
            state = "genericStatus";
        }
        onExpandLauncher: {
            state = "appSpecific";
        }
    }
}
