import QtQuick 2.0

import "../Utils"

SlidingItemArea {
    slidingTargetItem: notificationGradientRectangle
    filterChildren: true

    Rectangle {
        id: notificationGradientRectangle

        property color buttonColor: "#2f2f2f";
        radius: 15

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: 0
        width: parent.width

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(notificationGradientRectangle.buttonColor, 1.5) }
            GradientStop { position: 1.0; color: notificationGradientRectangle.buttonColor }
        }

        Row {
            id: fullNotificationRow

            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: model.icon
                width: notificationGradientRectangle.height * 0.8;
                height: notificationGradientRectangle.height * 0.8;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                text: model.htmlContent
            }
        }
    }
}
