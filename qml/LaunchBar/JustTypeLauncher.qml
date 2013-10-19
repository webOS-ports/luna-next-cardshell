import QtQuick 2.0
import LunaNext 0.1

Item {
    id: justTypeLauncher

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: justTypeLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: justTypeLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: justTypeLauncher; anchors.top: parent.top; anchors.bottom: parent.bottom }
            PropertyChanges { target: justTypeLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: justTypeLauncher; property: "visible" }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 150 }
            }
        }
    ]
}
