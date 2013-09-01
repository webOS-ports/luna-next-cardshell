import QtQuick 2.0
import LunaNext 0.1

import "../LunaSysAPI" as LunaSysAPI

Rectangle {
    id: appLauncher

    property Item itemAboveLauncher
    property Item itemUnderLauncher

    state: "hidden"
    visible: false
    anchors.top: itemUnderLauncher.top

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: appLauncher; anchors.bottom: undefined; anchors.top: itemUnderLauncher.top }
            PropertyChanges { target: appLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: appLauncher; anchors.bottom: itemUnderLauncher.top; anchors.top: itemAboveLauncher.bottom }
            PropertyChanges { target: appLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: appLauncher; property: "visible" }
                AnchorAnimation { duration: 300 }
            }
        }
    ]

    color: "#2f2f2f"

    LunaSysAPI.ApplicationModel {
        id: appsModel
    }

    GridView {
        anchors.fill: parent
        model: appsModel

        delegate: LaunchableAppIcon {
            width: 128

            appTitle: model.title
            appIcon: model.icon
            appId: model.id
            showTitle: true
        }
    }

    function toggleDisplay()
    {
        if( state === "visible" )
            state = "hidden"
        else
            state = "visible"
    }
}
