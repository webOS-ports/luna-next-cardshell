import QtQuick 2.0
import QtQuick.Layouts 1.0

ColumnLayout {
    id: launchableAppIcon

    property string appIcon
    property string appTitle
    property string appId
    property bool showTitle: false

    signal startLaunchApplication(string appId)

    spacing: 0

    Image {
        Layout.fillHeight: true

        anchors.left: launchableAppIcon.left
        anchors.right: launchableAppIcon.right

        fillMode: Image.PreserveAspectFit

        sourceSize.height: height
        sourceSize.width: width
        source: launchableAppIcon.appIcon

        MouseArea {
            anchors.fill: parent
            onClicked:  startLaunchApplication(launchableAppIcon.appId);
        }
    }
    Text {
        Layout.fillHeight: false

        anchors.left: launchableAppIcon.left
        anchors.right: launchableAppIcon.right

        visible: launchableAppIcon.showTitle

        color: "white"
        text: launchableAppIcon.appTitle
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
}
