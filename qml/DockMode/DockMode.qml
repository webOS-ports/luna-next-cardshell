import QtQuick 2.0
import LunaNext.Common 0.1

Item {
    id: dockMode

    property bool dockModeActive: false

    visible: dockModeActive

    onDockModeActiveChanged: {
        console.log("DockMode changed to " + dockModeActive);
        if (dockModeActive)
            clocksLoader.sourceComponent = clocksComponent;
        else
            clocksLoader.sourceComponent = null;
    }

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            service.subscribe("luna://com.palm.display/control/lockStatus", "{\"subscribe\":true}", handleLockStatus, handleError);
        }

        function handleLockStatus(message) {
            console.log("DockMode: Got lock status " + message.payload);
            var response = JSON.parse(message.payload);

            dockModeActive = (response.lockState === "dockmode");
        }

        function handleError(message) {
            console.log("Service error: " + message);
        }
    }

    Loader {
        id: clocksLoader

        width: parent.width;
        height: parent.height;
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Component {
        id: clocksComponent

        Clocks {
            id: clocks
            mainTimerRunning: dockModeActive
        }
    }
}

