import QtQuick 2.0
import LunaNext 0.1

Column {
    id: launchableAppIcon

    property string appIcon
    property string appTitle
    property string appId
    property bool showTitle: false

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    Image {
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        fillMode: Image.PreserveAspectFit

        sourceSize.height: height
        sourceSize.width: width
        source: launchableAppIcon.appIcon

        MouseArea {
            anchors.fill: parent
            onClicked: launchableAppIcon.lunaNextLS2Service.call("luna://com.palm.applicationManager/launch", JSON.stringify({"id": launchableAppIcon.appId}), undefined, handleError)

            function handleError(message) {
                console.log("Could not start application " + launchableAppIcon.appId + " : " + message);
            }
        }
    }
    Text {
        visible: launchableAppIcon.showTitle
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        color: "white"
        text: launchableAppIcon.appTitle
    }
}
