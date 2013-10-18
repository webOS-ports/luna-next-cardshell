import QtQuick 2.0
import LunaNext 0.1

// this should be a plugin import
import "../WindowManager/WindowManagerServices.js" as WindowManagerServices

Item {
    id: dummyWindow
    property int winId: 0
    property string appId: "org.webosports.tests.dummywindow"
    property alias scale: windowRectangle.scale
    property int windowType: WindowType.Card

    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "black" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "Test Window App"
                font.pointSize: 20
                color: "white"
            }

            Text {
                text: "Current mode: " + WindowManagerServices.getWindowState(dummyWindow)
                font.pointSize: 20
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent;

                    onClicked: {
                        var currentState = WindowManagerServices.getWindowState(dummyWindow);
                        // switch to the next state
                        currentState = (currentState+1) % 4;

                        // Skip Invisible state
                        if (currentState === 0)
                            currentState = WindowState.Carded;

                        WindowManagerServices.setWindowState(dummyWindow, currentState);
                    }
                }
            }
            Text {
                text: "Add notification"
                font.pointSize: 20
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent;

                    onClicked: {
                        var newNotif = {
                            "icon": "../images/glow.png",
                            "content": "this is a new notification from DummyWindow"
                        };
                        WindowManagerServices.addNotification(newNotif);
                    }
                }
            }

            TextInput {
                text: "try me !"
            }
        }
    }

    function takeFocus() {
        console.log("DummyWindow: takeFocus()");
    }
    function changeSize(w, h) {
        console.log("DummyWindow: changeSize(" + w + ", " + h + ")");
    }
}
