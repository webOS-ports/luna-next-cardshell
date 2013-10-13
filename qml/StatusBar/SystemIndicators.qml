import QtQuick 2.0

Row {
    id: indicatorsRow

    SequentialAnimation {
        id: hideIndicatorAnimation

        ParallelAnimation {
            NumberAnimation { target: hideIndicatorAnimation.target; properties: "opacity"; to: 0; duration: 200 }
            NumberAnimation { target: hideIndicatorAnimation.target; properties: "width"; to: 0; duration: 400 }
        }
        PropertyAction { target: hideIndicatorAnimation.target; properties: "visible"; value: false }

        function hideItem(itemToHide) {
            target = itemToHide;
            start();
        }

        property Item target
    }

    BatteryIndicator {
        id: batteryIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        batteryLevel: 0

        MouseArea {
            anchors.fill: parent
            onClicked: { hideIndicatorAnimation.hideItem(parent) }
        }
    }
}
