import QtQuick 2.0

Item {
    property Item gestureArea
    property Item windowManager

    // App launcher, which can slide up or down on demand
    FullLauncher {
        id: fullLauncherInstance

        anchors.left: parent.left
        anchors.right: parent.right
    }

    // bottom area: launcher bar
    LaunchBar {
        id: launchBarInstance

        height: windowManager.computeFromLength(80);
        anchors.left: parent.left
        anchors.right: parent.right

        onToggleLauncherDisplay: switchToNextState();
    }

    state: "launchbar"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: launchBarInstance; state: "hidden" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
        },
        State {
            name: "launchbar"
            PropertyChanges { target: launchBarInstance; state: "visible" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
        },
        State {
            name: "fullLauncher"
            PropertyChanges { target: launchBarInstance; state: "visible" }
            PropertyChanges { target: fullLauncherInstance; state: "visible" }
        }
    ]

    Connections {
        target: gestureArea
        onSwipeUpGesture:{
            switchToNextState();
        }
        onTapGesture: {
            switchToNextState();
        }
    }

    Connections {
        target: windowManager
        onSwitchToMaximize: {
            state = "hidden";
        }
        onSwitchToFullscreen: {
            state = "hidden";
        }
    }

    function switchToNextState() {
        if( state === "hidden" ) {
            state = "launchbar";
        }
        else if( state === "launchbar" ) {
            state = "fullLauncher";
        }
        else if( state === "fullLauncher" ) {
            state = "launchbar";
        }
    }
}
