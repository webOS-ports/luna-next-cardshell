import QtQuick 2.0

Item {
    id: justTypeFieldItem
    property Item windowManagerInstance

    signal showJustType(int pressedKey)

    Rectangle {
        anchors.fill: parent

        radius: windowManagerInstance.cornerRadius

        border.color: "#5a5a5a"
        border.width: 2

        color: "#d7d7d7"
        opacity: 0.2
    }
    Text {
        anchors.fill: parent
        anchors.leftMargin: parent.width * 0.02

        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.VerticalFit
        text: "Just Type..."
    }
    MouseArea {
        anchors.fill: parent
        onClicked: justTypeFieldItem.showJustType(0)
    }
    Keys.onPressed: if(visible && opacity>0) {
                        showJustType(event.key);
                    }


    states: [
        State {
            name: "hidden"
            PropertyChanges { target: justTypeFieldItem; opacity: 0 }
            PropertyChanges { target: justTypeFieldItem; focus: false }
        },
        State {
            name: "visible"
            PropertyChanges { target: justTypeFieldItem; opacity: 1 }
            PropertyChanges { target: justTypeFieldItem; focus: true }
        }
    ]

    transitions: Transition { NumberAnimation { duration: 100 } }

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "visible";
        }
        onSwitchToMaximize: {
            state = "hidden";
        }
        onSwitchToFullscreen: {
            state = "hidden";
        }
        onSwitchToCardView: {
            state = "visible";
        }
        onExpandLauncher: {
            state = "hidden";
        }
    }

    Component.onCompleted: state = "visible"
}
