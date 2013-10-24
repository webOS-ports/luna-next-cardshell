import QtQuick 2.0

QtObject {
    property string name
    property string method
    property bool usePrivateBus: false

    signal initialized

    Component.onCompleted: {
        initialized();
    }

    function call(serviceURI, jsonArgs, returnFct, handleError) {
        var args = JSON.parse(jsonArgs);
        if( serviceURI === "luna://com.palm.applicationManager/listLaunchPoints" ) {
            listLaunchPoints_call(args, returnFct, handleError);
        }
        else if( serviceURI === "luna://com.palm.applicationManager/launch" ) {
            launchApp_call(args, returnFct, handleError);
        }
        else if( serviceURI === "luna://com.palm.applicationManager/createNotification" ) {
            createNotification_call(args, returnFct, handleError);
        }

        else {
            handleError("unrecognized call: " + serviceURI);
        }
    }

    function subscribe(serviceURI, jsonArgs, returnFct, handleError) {
        var args = JSON.parse(jsonArgs);
        if( serviceURI === "luna://com.palm.bus/signal/registerServerStatus" &&
            args.serviceName === "com.palm.applicationManager")
        {
            returnFct(JSON.stringify({"connected":true}));
        }
        else if( serviceURI === "luna://com.palm.applicationManager/launchPointChanges" && args.subscribe)
        {
            returnFct(JSON.stringify({"subscribed":true})); // simulate subscription answer
            returnFct("{}");
        }
    }

    function registerMethod(category, name, callback) {
        /* do nothing */
    }

    function listLaunchPoints_call(jsonArgs, returnFct, handleError) {
        returnFct(JSON.stringify({"returnValue": true,
                    "launchPoints": [
             { "title": "Calendar", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Email", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Calculator", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png", "showInSearch": false },
             { "title": "Snowshoe", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "This is a long title", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "This_is_also_a_long_title", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Preware 5", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "iOS", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Oh My", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test1", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test2", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test3", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test5", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test5bis", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test6", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "End Of All Tests", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" }
           ]}));
    }

    function launchApp_call(jsonArgs, returnFct, handleError) {
        // The JSON params can contain "id" (string) and "params" (object)
        if( jsonArgs.id === "org.webosports.tests.dummyWindow" ) {
            // start a DummyWindow
            // Simulate the attachement of a new window to the stub Wayland compositor
            compositor.createFakeWindow("DummyWindow", jsonArgs);
        }
        else if( jsonArgs.id === "org.webosports.tests.fakeOverlayWindow" ) {
            // start a FakeOverlayWindow
            // Simulate the attachement of a new window to the stub Wayland compositor
            compositor.createFakeWindow("FakeOverlayWindow", jsonArgs);
        }
        else if( jsonArgs.id === "org.webosports.tests.fakeDashboardWindow" ) {
            // start a FakeDashboardWindow
            // Simulate the attachement of a new window to the stub Wayland compositor
            compositor.createFakeWindow("FakeDashboardWindow", jsonArgs);
        }
        else {
            handleError("Error: parameter 'id' not specified");
        }
    }

    function createNotification_call(jsonArgs, returnFct, handleError) {
        // The JSON params can contain "id" (string) and "params" (object)
        if( jsonArgs.type === "dashboard" ) {
            // start a FakeDashboardWindow

            // Simulate the attachement of a new dashboard window to the stub Wayland compositor
            compositor.createFakeWindow("FakeDashboardWindow", jsonArgs);
        }
        else {
            handleError("Error: parameter 'id' not specified");
        }
    }
}
