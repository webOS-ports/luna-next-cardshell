import QtQuick 2.0

Row {
    SequentialAnimation {
        id: removeIndicatorAnimation

        NumberAnimation { target: removeIndicatorAnimation.target; properties: "opacity"; to: 0; duration: 200 }
        NumberAnimation { target: removeIndicatorAnimation.target; properties: "width"; to: 0; duration: 200 }
        PropertyAction { target: removeIndicatorAnimation.target; properties: "visible"; value: false }

        function removeItem(itemToRemove) {
            target = itemToRemove;
            start();
        }

        property Item target
    }

    BatteryIndicator {
        width: 18
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
            anchors.fill: parent
            onClicked: { removeIndicatorAnimation.removeItem(parent) }
        }
    }
}
