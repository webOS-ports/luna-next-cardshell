/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0

import "LunaServiceRegistering.js" as LSRegisteredMethods

QtObject {
    property string name
    property string method
    property bool usePrivateBus: false

    signal initialized

    Component.onCompleted: {
        initialized();
    }

    function call(serviceURI, jsonArgs, returnFct, handleError) {
        console.log("LunaService::call called with serviceURI=" + serviceURI + ", args=" + jsonArgs);
        var args = JSON.parse(jsonArgs);
        if( serviceURI === "luna://com.palm.applicationManager/listLaunchPoints" ) {
            listLaunchPoints_call(args, returnFct, handleError);
        }
        else if( serviceURI === "luna://com.palm.applicationManager/launch" ) {
            launchApp_call(args, returnFct, handleError);
        }
        else if( serviceURI === "palm://com.palm.applicationManager/getAppInfo" ) {
            giveFakeAppInfo_call(args, returnFct, handleError);
        }
        else {
            // Embed the jsonArgs into a payload message
            var message = { applicationId: "org.webosports.tests.dummyWindow", payload: jsonArgs };
            if( !(LSRegisteredMethods.executeMethod(serviceURI, message)) ) {
                handleError("unrecognized call: " + serviceURI);
            }
        }
    }

    function subscribe(serviceURI, jsonArgs, returnFct, handleError) {
        var args = JSON.parse(jsonArgs);
        if( serviceURI === "palm://com.palm.bus/signal/registerServerStatus" ||
            serviceURI === "luna://com.palm.bus/signal/registerServerStatus" )
        {
            returnFct({"payload": JSON.stringify({"connected": true})});
        }
        else if( serviceURI === "luna://com.palm.applicationManager/launchPointChanges" && args.subscribe)
        {
            returnFct({"payload": JSON.stringify({"subscribed": true})}); // simulate subscription answer
            returnFct({"payload": JSON.stringify({})});
        }
        else if( serviceURI === "luna://org.webosports.bootmgr/getStatus" && args.subscribe )
        {
            console.log("bootmgr status: normal");
            returnFct({"payload": JSON.stringify({"subscribed":true, "state": "normal"})}); // simulate subscription answer
        }
        else if( serviceURI === "palm://com.palm.systemservice/getPreferences" && args.subscribe)
        {
            returnFct({"payload": JSON.stringify({"subscribed": true})}); // simulate subscription answer
            returnFct({"payload": JSON.stringify({"wallpaper": { "wallpaperFile": Qt.resolvedUrl("../../../../images/background.jpg")}})});
        }
        else if (serviceURI === "luna://org.webosports.audio/getStatus")
        {
            returnFct({"payload": JSON.stringify({"volume":54,"mute":false})});
        }
        else if (serviceURI === "palm://com.palm.bus/signal/addmatch" )
        {
            LSRegisteredMethods.addRegisteredMethod("palm://" + name + args.category + "/" + args.name, returnFct);
            returnFct({"payload": JSON.stringify({"subscribed": true})}); // simulate subscription answer
        }
    }

    function registerMethod(category, fct, callback) {
        console.log("registering " + "luna://" + name + category + fct);
        LSRegisteredMethods.addRegisteredMethod("luna://" + name + category + fct, callback);
    }

    function addSubscription() {
        /* do nothing */
    }

    function replyToSubscribers(path, callerAppId, jsonArgs) {
        console.log("replyToSubscribers " + "luna://" + name + path);
        LSRegisteredMethods.executeMethod("luna://" + name + path, {"applicationId": callerAppId, "payload": jsonArgs});
    }

    function listLaunchPoints_call(jsonArgs, returnFct, handleError) {
        returnFct({"payload": JSON.stringify({"returnValue": true,
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
           ]})});
    }

    function giveFakeAppInfo_call(args, returnFct, handleError) {
        returnFct({"payload": JSON.stringify({"returnValue": true, "appInfo": { "appmenu": "Fake App" } })});
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
        else if( jsonArgs.id === "org.webosports.tests.fakePopupAlertWindow" ) {
            // start a FakeDashboardWindow
            // Simulate the attachement of a new window to the stub Wayland compositor
            compositor.createFakeWindow("FakePopupAlertWindow", jsonArgs);
        }
        else {
            handleError("Error: parameter 'id' not specified");
        }
    }

    function createNotification_call(jsonArgs, returnFct, handleError) {

        if( jsonArgs ) {
            var callerAppId = "org.webosports.tests.dummyWindow"; // hard-coded

            replyToSubscribers("/createNotification", callerAppId, jsonArgs);
        }
        else {
            handleError("Error: parameter 'id' not specified");
        }
    }
}
