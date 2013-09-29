import QtQuick 2.0
import LunaNext 0.1

Item {
    property Item gestureArea
    property Item windowManagerInstance

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    // App launcher, which can slide up or down on demand
    FullLauncher {
        id: fullLauncherInstance

        anchors.left: parent.left
        anchors.right: parent.right
    }

    // bottom area: launcher bar
    LaunchBar {
        id: launchBarInstance

        height: windowManagerInstance.computeFromLength(80);
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
            state = "launchbar";
        }
        onExpandLauncher: {
            state = "fullLauncher";
        }
    }

    Connections {
        target: launchBarInstance
        onStartLaunchApplication: {
            state = "hidden";
            lunaNextLS2Service.call("luna://com.palm.applicationManager/launch", JSON.stringify({"id": appId}), undefined, handleLaunchAppError)
        }
    }
    Connections {
        target: fullLauncherInstance
        onStartLaunchApplication: {
            state = "hidden";
            lunaNextLS2Service.call("luna://com.palm.applicationManager/launch", JSON.stringify({"id": appId}), undefined, handleLaunchAppError)
        }
    }

    function handleLaunchAppError(message) {
        console.log("Could not start application : " + message);
        state = "launchbar";
    }

    function switchToNextState() {
        if( state === "hidden" ) {
            windowManagerInstance.cardViewMode();
        }
        else if( state === "launchbar" ) {
            windowManagerInstance.expandedLauncherMode();
        }
        else if( state === "fullLauncher" ) {
            windowManagerInstance.cardViewMode();
        }
    }
}
