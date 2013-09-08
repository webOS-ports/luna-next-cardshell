import QtQuick 2.0
import LunaNext 0.1

Item {
    property Item gestureArea
    property Item windowManager

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
            if( launchBarInstance.visible )
                launchBarInstance.toggleLauncherDisplay();
        }
        onTapGesture: {
            if( launchBarInstance.visible )
                launchBarInstance.toggleLauncherDisplay();
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
        onSwitchToCard: {
            state = "launchbar";
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
        console.log("Could not start application " + launchableAppIcon.appId + " : " + message);
    }

    function switchToNextState() {
        if( state === "launchbar" ) {
            state = "fullLauncher";
        }
        else if( state === "fullLauncher" ) {
            state = "launchbar";
        }
    }
}
