import QtQuick 2.0
import QtQuick.Layouts 1.0
import LunaNext 0.1

/// The status bar can be divided in four main regions: app menu, title, system indicators, system menu
/// [ -- app menu -- |                       --- indicators -- | -- system menu -- ]
///                  [           --- title ---                 ]
Rectangle {
    id: statusBarItem
    color: "black"

    /// app menu
    Item {
        id: appMenuItem
        anchors.verticalCenter: statusBarItem.verticalCenter
        anchors.left: statusBarItem.left

        implicitWidth: appMenuText.implicitWidth

        Text {
            id: appMenuText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right

            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: 20
            text: "App menu"
        }
    }

    /// system menu
    Item {
        id: systemMenuStatusBarItem

        anchors.verticalCenter: statusBarItem.verticalCenter
        anchors.right: statusBarItem.right

        implicitWidth: systemMenuText.implicitWidth

        Text {
            id: systemMenuText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right

            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: 20
            text: "System menu"
        }
    }

    /// general title
    Item {
        id: titleItem
        anchors.verticalCenter: statusBarItem.verticalCenter
        anchors.left: appMenuItem.right
        anchors.right: systemMenuStatusBarItem.left

        implicitWidth: titleText.implicitWidth

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right

            horizontalAlignment: Text.AlignHCenter

            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: 20
            font.bold: true
            text: Qt.formatDateTime(new Date(), "dd.MM.yyyy")
        }
    }

    /// system indicators
    SystemIndicators {
        id: systemIndicatorsStatusBarItem

        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.right: systemMenuStatusBarItem.left
    }
}
