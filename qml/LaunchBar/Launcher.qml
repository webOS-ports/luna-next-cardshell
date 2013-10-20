import QtQuick 2.0
import LunaNext 0.1

Item {
    id: launcherItem

    property Item gestureArea
    property Item windowManagerInstance

    property bool launcherActive: state === "fullLauncher" || state === "justTypeLauncher"

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    Keys.forwardTo: [ justTypeFieldInstance ]

    // JustType field
    JustTypeField {
        id: justTypeFieldInstance

        windowManagerInstance: launcherItem.windowManagerInstance

        anchors.top: parent.top
        anchors.topMargin: launcherItem.windowManagerInstance.computeFromLength(10);
        width: parent.width * 0.8
        height: launcherItem.windowManagerInstance.computeFromLength(40);
        anchors.horizontalCenter: parent.horizontalCenter

        onShowJustType: {
            if( !!__justTypeLauncherWindowWrapper ) {
                launcherItem.state = "justTypeLauncher";
            }
        }
    }

    // App launcher, which can slide up or down on demand
    FullLauncher {
        id: fullLauncherInstance

        iconSize: windowManagerInstance.computeFromLength(40);
        bottomMargin: launchBarInstance.height;

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

    // JustType launcher window container
    JustTypeLauncher {
        id: justTypeLauncherInstance

        anchors.left: parent.left
        anchors.right: parent.right
    }

    state: "launchbar"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: launchBarInstance; state: "hidden" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
            PropertyChanges { target: justTypeFieldInstance; state: "hidden" }
            PropertyChanges { target: justTypeLauncherInstance; state: "hidden" }
        },
        State {
            name: "launchbar"
            PropertyChanges { target: launchBarInstance; state: "visible" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
            PropertyChanges { target: justTypeFieldInstance; state: "visible" }
            PropertyChanges { target: justTypeLauncherInstance; state: "hidden" }
        },
        State {
            name: "fullLauncher"
            PropertyChanges { target: launchBarInstance; state: "visible" }
            PropertyChanges { target: fullLauncherInstance; state: "visible" }
            PropertyChanges { target: justTypeFieldInstance; state: "hidden" }
            PropertyChanges { target: justTypeLauncherInstance; state: "hidden" }
        },
        State {
            name: "justTypeLauncher"
            PropertyChanges { target: launchBarInstance; state: "hidden" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
            PropertyChanges { target: justTypeFieldInstance; state: "hidden" }
            PropertyChanges { target: justTypeLauncherInstance; state: "visible" }
            StateChangeScript {
                script: {
                    if (__justTypeLauncherWindowWrapper) {
                        // take focus for receiving input events
                        __justTypeLauncherWindowWrapper.takeFocus();
                    }
                }
            }
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

        onSwitchToLauncherView: {
            if( !launcherActive ) {
                state = "fullLauncher";
            }
        }
    }

    Connections {
        target: launchBarInstance
        onStartLaunchApplication: {
            state = "launchbar";
            lunaNextLS2Service.call("luna://com.palm.applicationManager/launch", JSON.stringify({"id": appId}), undefined, handleLaunchAppError)
        }
    }
    Connections {
        target: fullLauncherInstance
        onStartLaunchApplication: {
            state = "launchbar";
            lunaNextLS2Service.call("luna://com.palm.applicationManager/launch", JSON.stringify({"id": appId}), undefined, handleLaunchAppError)
        }
    }

    function handleLaunchAppError(message) {
        console.log("Could not start application : " + message);
        state = "launchbar";
    }

    function expandLauncher() {
        state = "fullLauncher";
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

    function initJustTypeLauncherApp(windowWrapper, winId) {
        if( windowWrapper.windowType === WindowType.Launcher && !__justTypeLauncherWindowWrapper )
        {
            __justTypeLauncherWindowWrapper = windowWrapper;
            windowWrapper.setNewParent(justTypeLauncherInstance, false);
        }
    }

    property Item __justTypeLauncherWindowWrapper;
}
