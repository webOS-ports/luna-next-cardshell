import QtQuick 2.0

Column {
    id: launchableAppIcon

    property string appIcon
    property string appTitle
    property string appId
    property bool showTitle: false

    signal startLaunchApplication(string appId)

    Image {
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter

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
        width: parent.width
        visible: launchableAppIcon.showTitle
        anchors.horizontalCenter: parent.horizontalCenter
        color: "white"
        text: launchableAppIcon.appTitle
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        font.pixelSize: 25
        elide: Text.ElideRight
    }
}
