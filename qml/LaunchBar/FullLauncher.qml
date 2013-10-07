import QtQuick 2.0

import "../LunaSysAPI" as LunaSysAPI

Rectangle {
    id: fullLauncher

    property real iconSize: 64

    signal startLaunchApplication(string appId)

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
        id: gridview

        model: appsModel

        cellWidth: 115
        cellHeight: cellWidth + 30
        width: Math.floor(parent.width / cellWidth) * cellWidth
        height: parent.height

        anchors.horizontalCenter: parent.horizontalCenter

        header: Item { height: 30 }
        footer: Item { height: 20 }

        delegate: LaunchableAppIcon {
                width: fullLauncher.iconSize

                appTitle: model.title
                appIcon: model.icon
                appId: model.id
                showTitle: true

                onStartLaunchApplication: fullLauncher.startLaunchApplication(appId);
            }
    }
}
