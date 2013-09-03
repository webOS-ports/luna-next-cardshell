import QtQuick 2.0
import LunaNext 0.1

Item {
    id: statusBarItem

    Rectangle {
        anchors.fill: statusBarItem
        color: "black"

        Text {
            anchors.centerIn: parent
            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: 24
            font.bold: true
            text: Qt.formatDateTime(new Date(), "dd.MM.yyyy")
        }
    }
}
