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
        font.pixelSize: bgCenter.height * 0.4;
        text: "Just type."
        color: "white"
        font.family: Settings.fontStatusBar
    }
    MouseArea {
        anchors.fill: parent
        onClicked: justTypeFieldItem.showJustType(0)
    }

    Keys.onPressed: {
        if(visible && opacity>0 && __isDisplayableKey(event.key) ) {
                        showJustType(event.key);
                        event.accepted = true;
        }
    }

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: justTypeFieldItem; opacity: 0 }
        },
        State {
            name: "visible"
            PropertyChanges { target: justTypeFieldItem; opacity: 1 }
        }
    ]

    transitions: Transition { NumberAnimation { duration: 100 } }

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "hidden";
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
        onSwitchToLauncherView: {
            state = "hidden";
        }
    }

    Component.onCompleted: state = "visible"

    function __isDisplayableKey(key)
    {
        /*
         * In QtQuick the keycode that can be actually displayed have a value
         * between 0x00 and 0xff.
        */

        if( key <= 0x0ff )
            return true;
        return false;
    }
}
