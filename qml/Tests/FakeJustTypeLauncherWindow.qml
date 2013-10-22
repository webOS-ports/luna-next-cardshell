import QtQuick 2.0
import LunaNext 0.1

FakeWindowBase {
    id: fakeJustTypeWindow

    appId: "org.webosports.tests.fakeJustTypeLauncher"
    property alias scale: windowRectangle.scale
    windowType: WindowType.Launcher

    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "blue" }
        }
    }
}
