import QtQuick 2.0
import LunaNext 0.1

import "../LunaSysAPI" as LunaSysAPI

Rectangle {
    id: fullLauncher

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: fullLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: fullLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: fullLauncher; anchors.top: parent.top; anchors.bottom: parent.bottom }
            PropertyChanges { target: fullLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: fullLauncher; property: "visible" }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 150 }
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
}
