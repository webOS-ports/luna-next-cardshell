import QtQuick 2.0

Column {
    id: launchableAppIcon

    property string appIcon
    property string appTitle
    property string appId
    property string appParams: "{}"
    property bool showTitle: false

    property real iconSize: 64

    signal startLaunchApplication(string appId, string appParams)

    Image {
        width: iconSize
        height: iconSize
        anchors.horizontalCenter: parent.horizontalCenter

        fillMode: Image.PreserveAspectFit

        sourceSize.height: height
        sourceSize.width: width
        source: launchableAppIcon.appIcon

        MouseArea {
            anchors.fill: parent
            onClicked:  startLaunchApplication(launchableAppIcon.appId, launchableAppIcon.appParams);
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
        font.pixelSize: iconSize*0.3
        font.bold: true
        maximumLineCount: 2
        elide: Text.ElideRight
    }
}
