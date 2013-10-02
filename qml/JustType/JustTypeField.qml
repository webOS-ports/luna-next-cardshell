import QtQuick 2.0
import LunaNext 0.1

Item {
    id: justTypeFieldItem
    property Item windowManagerInstance

    signal showJustType(int pressedKey)

    Image {
        id: bgLeft
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: "../images/search-field-bg-launcher-left.png"
    }
    Image {
        id: bgRight
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: "../images/search-field-bg-launcher-right.png"
    }
    Image {
        id: bgCenter

        anchors.left: bgLeft.right
        anchors.right: bgRight.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        smooth: true

        source: "../images/search-field-bg-launcher-center.png"
    }
    Image {
        anchors.right: bgCenter.right
        anchors.verticalCenter: bgCenter.verticalCenter
        height: bgCenter.height * 0.8

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: "../images/search-button-launcher.png"
    }
    Text {
        anchors.fill: bgCenter

        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.VerticalFit
        text: "Just type..."
        color: "white"
        font.family: Settings.fontStatusBar
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
