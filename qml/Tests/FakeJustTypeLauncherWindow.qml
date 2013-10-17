import QtQuick 2.0
import LunaNext 0.1

// this should be a plugin import
import "../WindowManager/WindowManagerServices.js" as WindowManagerServices

Item {
    id: fakeJustTypeWindow
    property int winId: 0
    property string appId: "org.webosports.tests.fakeJustTypeLauncher"
    property alias scale: windowRectangle.scale
    property int windowType: WindowType.Launcher

    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "blue" }
        }
    }

    function takeFocus() {
        console.log("FakeJustTypeLauncherWindow: takeFocus()");
    }
    function changeSize(w, h) {
        console.log("FakeJustTypeLauncherWindow: changeSize(" + w + ", " + h + ")");
    }
}
