import QtQuick 2.0
import LunaNext 0.1

// this should be a plugin import
import "../WindowManager/WindowManagerServices.js" as WindowManagerServices

Item {
    id: fakeWindowBase
    property int winId: 0
    property string appId: "org.webosports.tests.fakewindowbase"
    property int windowType: WindowType.Card

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    height: 200
    width: 200

    function takeFocus() {
        console.log(fakeWindowBase + ": takeFocus()");
    }
    function changeSize(w, h) {
        console.log(fakeWindowBase + ": changeSize(" + w + ", " + h + ")");
    }
}
