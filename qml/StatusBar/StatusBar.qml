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
        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.left: statusBarItem.left

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        width: appMenuBgImageLeft.width + appMenuBgImageCenter.width + appMenuBgImageRight.width

        Image {
            id: appMenuBgImageLeft

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            fillMode: Image.PreserveAspectFit
            smooth: true

            source: "../images/statusbar/appname-background-left.png"
        }
        Image {
            id: appMenuBgImageCenter

            anchors.left: appMenuBgImageLeft.right
            width: appMenuText.implicitWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            smooth: true

            source: "../images/statusbar/appname-background-center.png"
        }
        Image {
            id: appMenuBgImageRight

            anchors.left: appMenuBgImageCenter.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            fillMode: Image.PreserveAspectFit
            smooth: true

            source: "../images/statusbar/appname-background-right.png"
        }
        Text {
            id: appMenuText

            anchors.left: appMenuBgImageCenter.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            color: "white"
            font.family: Settings.fontStatusBar
            font.pointSize: 20
            fontSizeMode: Text.VerticalFit
            text: "App menu"
        }
    }

    /// system menu
    Item {
        id: systemMenuStatusBarItem

        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.right: statusBarItem.right

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        implicitWidth: systemMenuText.implicitWidth

        Text {
            id: systemMenuText
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right

            horizontalAlignment: Text.AlignRight

            color: "white"
            font.family: Settings.fontStatusBar
            font.pointSize: 20
            fontSizeMode: Text.VerticalFit
            text: "System menu"
        }
    }

    /// general title
    Item {
        id: titleItem
        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.left: appMenuItem.right
        anchors.right: systemMenuStatusBarItem.left

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        implicitWidth: titleText.implicitWidth

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

    /// system indicators
    SystemIndicators {
        id: systemIndicatorsStatusBarItem

        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.right: systemMenuStatusBarItem.left

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2
    }
}
