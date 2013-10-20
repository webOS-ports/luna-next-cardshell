import QtQuick 2.0
import LunaNext 0.1

// this should be a plugin import
import "../WindowManager/WindowManagerServices.js" as WindowManagerServices

FakeWindowBase {
    id: dummyWindow

    appId: "org.webosports.tests.dummyWindow"
    windowType: WindowType.Card

    height: 200
    width: 600

    property alias scale: windowRectangle.scale

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
                        lunaNextLS2Service.call("luna://com.palm.applicationManager/createNotification",
                                                JSON.stringify({"type": "dashboard",
                                                                "appId": "org.webosports.tests.fakeJustTypeLauncher",
                                                                "appIcon": "../images/glow.png"}),
                                                undefined, undefined)
                    }
                }
            }
            Text {
                text: "Kill me"
                font.pointSize: 20
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent;

                    onClicked: {
                        // commit suicide
                        dummyWindow.destroy();
                    }
                }
            }

            TextInput {
                text: "try me !"
            }
        }
    }
}
