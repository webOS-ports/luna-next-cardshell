import QtQuick 2.0
import LunaNext 0.1

Item {
    id: overlayWindowItem

    state: "hidden"
    opacity: 0

    property Item overlaysManagerInstance
    anchors.top: overlaysManagerInstance.bottom

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: overlayWindowItem; anchors.top: overlaysManagerInstance.bottom; anchors.bottom: undefined }
            PropertyChanges { target: overlayWindowItem; opacity: 0 }
        },
        State {
            name: "visible"
            AnchorChanges { target: overlayWindowItem; anchors.top: undefined; anchors.bottom: overlaysManagerInstance.bottom }
            PropertyChanges { target: overlayWindowItem; opacity: 1 }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            ParallelAnimation {
                NumberAnimation { target: overlayWindowItem; properties: "opacity"; easing.type:Easing.InOutQuad; duration: 400 }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 300 }
            }
        }
    ]
}
