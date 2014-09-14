import QtQuick 2.0
import LunaNext.Common 0.1

Item {
    id: notification

    property string title: "(no title)"
    property string body: "(no summary)"
    property url iconUrl: Qt.resolvedUrl("images/default-app-icon.png");

    Rectangle {
        id: iconBox
        width: Units.gu(6)
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "#393939"
        radius: 8

        Image {
            width: parent.width / 2
            anchors.centerIn: parent
            source: "images/default-app-icon.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    Rectangle {
        id: mainContent
        anchors.left: iconBox.right
        anchors.leftMargin: Units.gu(1) / 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "#393939"
        radius: 8

        Text {
            id: summaryText
            font.bold: true
            font.pixelSize: FontUtils.sizeToPixels("medium")
            color: "white"
            text: notification.title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 3
            anchors.leftMargin: 10
            anchors.bottomMargin: 5
        }

        Text {
            id: bodyText
            font.pixelSize: FontUtils.sizeToPixels("small")
            font.bold: false
            color: "white"
            text: notification.body
            anchors.top: summaryText.bottom
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.bottomMargin: 3
        }
    }
}
