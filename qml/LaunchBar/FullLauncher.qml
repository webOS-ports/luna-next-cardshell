import QtQuick 2.0

import "../LunaSysAPI" as LunaSysAPI

Rectangle {
    id: fullLauncher

    property real iconSize: 64
    property real bottomMargin: 80

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

        property real appIconWidth: iconSize*1.5
        property real appIconHMargin: function (parent, appIconWidth) {
            var nbCellsPerLine = Math.floor(parent.width / (appIconWidth + 10));
            var remainingHSpace = parent.width - nbCellsPerLine * appIconWidth;
            return Math.floor(remainingHSpace / nbCellsPerLine);
        } (parent, appIconWidth)

        cellWidth: appIconWidth + appIconHMargin
        cellHeight: iconSize + iconSize*0.4*2 // we give margin for two lines of text

        width: Math.floor(parent.width / cellWidth) * cellWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fullLauncher.bottomMargin
        clip: true

        header: Item { height: 30 }
        footer: Item { height: 20 }

        delegate: LaunchableAppIcon {
                width: gridview.appIconWidth

                appTitle: model.title
                appIcon: model.icon
                appId: model.id
                showTitle: true

                iconSize: fullLauncher.iconSize

                onStartLaunchApplication: fullLauncher.startLaunchApplication(appId);
            }
    }
}
