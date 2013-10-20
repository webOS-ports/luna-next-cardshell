import QtQuick 2.0
import QtQuick.Controls 1.0
import LunaNext 0.1

FakeWindowBase {
    id: fakeOverlayWindow

    appId: "org.webosports.tests.fakeOverlayWindow"
    windowType: WindowType.Overlay

    property string appIcon

    height: 150 + Math.random()*50

    property alias scale: windowRectangle.scale

    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "red" }
        }

        Row {
            anchors.centerIn: parent

            Button {
                text: "Hide me"
                onClicked: {
                    fakeOverlayWindow.visible = false;
                    showTimer.start();
                }

                Timer {
                    id: showTimer
                    interval: 3000
                    onTriggered: fakeOverlayWindow.visible = true
                }
            }
            Button {
                text: "Key"
                checkable: true
            }
        }
    }
}
