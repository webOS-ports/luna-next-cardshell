import QtQuick 2.0
import LunaNext 0.1

Item {
    id: appMenuItem

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
        width: appMenuText.contentWidth
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
