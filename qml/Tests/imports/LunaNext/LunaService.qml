import QtQuick 2.0

QtObject {
    property string name
    property string method
    property bool usePrivateBus: false

    function call(serviceURI, jsonArgs, returnFct, handleError) {
        var args = JSON.parse(jsonArgs);
        if( serviceURI === "luna://com.palm.applicationManager/listApps" ) {
            listApps_call(args, returnFct, handleError);
        }
        else if( serviceURI === "luna://com.palm.applicationManager/launch" ) {
            launchApp_call(args, returnFct, handleError);
        }

        else {
            handleError("unrecognized call: " + serviceURI);
        }
    }

    function listApps_call(jsonArgs, returnFct, handleError) {
        returnFct(JSON.stringify({"returnValue": true,
                    "apps": [
             { "title": "Calendar", "id": "com.palm.calendar", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Email", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Calculator", "id": "com.palm.calc", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png", "showInSearch": false },
             { "title": "Snowshoe", "id": "snowshoe", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "This is a long title", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "This_is_also_a_long_title", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Preware 5", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "iOS", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Oh My", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Test1", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Test2", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Test3", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Test5", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Test5bis", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "Test6", "id": "com.palm.email", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" },
             { "title": "End Of All Tests", "id": "snowshoe", "icon": "/usr/share/icons/hicolor/32x32/apps/gnome-panel-clock.png" }
           ]}));
    }

    function launchApp_call(jsonArgs, returnFct, handleError) {
        // The JSON params can contain "id" (string) and "params" (object)
        if( jsonArgs.id ) {
            // start a DummyWindow

            // Simulate the attachement of a new window to the stub Wayland compositor
            var windowComponent = Qt.createComponent("../../DummyWindow.qml");
            var window = windowComponent.createObject(compositor);
            compositor.windowAdded(window);
        }
        else {
            handleError("Error: parameter 'id' not specified");
        }
    }
}
