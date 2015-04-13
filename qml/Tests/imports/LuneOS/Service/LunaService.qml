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
    property string service

    property var lockStatusSubscriber
    property string currentLockStatus: "locked"

    property var deviceLockModeSubscriber
    property string deviceLockMode: "none"
    property string polcyState: "none"
    property int retriesLeft: 3
    property string configuredPasscode: "4242"

    signal initialized
    property var onResponse
    property var onError

    Component.onCompleted: {
        initialized();
    }

    function call(serviceURI, jsonArgs, returnFct, handleError) {
        if( arguments.length === 1 ) {
            // handle the short form of call
            return call(service+"/"+method, arguments[0], onResponse, onError);
        }
        else if(arguments.length === 3 ) {
            // handle the intermediate form of call
            return call(service+"/"+method, arguments[0], arguments[1], arguments[2]);
        }

        console.log("LunaService::call called with serviceURI=" + serviceURI + ", args=" + jsonArgs);

        var args =  JSON.parse(jsonArgs) ;
        if( serviceURI === "luna://com.palm.applicationManager/listLaunchPoints" ) {
            listLaunchPoints_call(args, returnFct, handleError);
        }
        else if( serviceURI === "luna://com.palm.applicationManager/launch" ) {
            launchApp_call(args, returnFct, handleError);
        }
        else if( serviceURI === "palm://com.palm.applicationManager/getAppInfo" ) {
            giveFakeAppInfo_call(args, returnFct, handleError);
        }
        else if (serviceURI === "luna://com.palm.display/control/setLockStatus") {
            setLockStatus_call(args, returnFct, handleError);
        }
        else if (serviceURI === "luna://com.palm.systemmanager/getDeviceLockMode") {
            getDeviceLockMode_call(args, returnFct, handleError);
        }
        else if (serviceURI === "luna://com.palm.systemmanager/matchDevicePasscode") {
            matchDevicePasscode_call(args, returnFct, handleError);
        }
        else if (serviceURI === "luna://com.palm.power/com/palm/power/batteryStatusQuery") {
            getBatteryStatusQuery_call(args, returnFct, handleError);
        }
        else if (serviceURI === "palm://com.palm.display/control/getProperty") {
            getDisplayProperty_call(args, returnFct, handleError);
        }
        else {
            // Embed the jsonArgs into a payload message
            var message = { applicationId: "org.webosports.tests.dummyWindow", payload: jsonArgs };
            if( !(LSRegisteredMethods.executeMethod(serviceURI, message)) ) {
                if (handleError)
                    handleError("unrecognized call: " + serviceURI);
            }
        }
    }

    function subscribe(serviceURI, jsonArgs, returnFct, handleError) {
        if( arguments.length === 1 ) {
            // handle the short form of subscribe
            return subscribe(service+"/"+method, arguments[0], onResponse, onError);
        }
        else if(arguments.length === 3 ) {
            // handle the intermediate form of subscribe
            return subscribe(service+"/"+method, arguments[0], arguments[1], arguments[2]);
        }

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
        else if (serviceURI === "luna://com.palm.display/control/lockStatus") {
            lockStatusSubscriber =  {func: returnFct};
            returnFct({payload: "{\"lockState\":\"" + currentLockStatus + "\"}"});
        }
        else if (serviceURI === "luna://com.palm.systemmanager/getDeviceLockMode") {
            deviceLockModeSubscriber = {func: returnFct};
            getDeviceLockMode_call(jsonArgs, returnFct, handleError);
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
             { "title": "Calendar", "id": "com.palm.app.calendar", "icon": "../images/default-app-icon.png" },
             { "title": "Email", "id": "com.palm.app.email", "icon": "../images/default-app-icon.png" },
             { "title": "Calculator", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png", "showInSearch": false },
             { "title": "Snowshoe", "id": "com.palm.app.browser", "icon": "../images/default-app-icon.png" },
             { "title": "This is a long title", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "This_is_also_a_long_title", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Preware 5", "id": "com.palm.app.swmanager", "icon": "../images/default-app-icon.png" },
             { "title": "iOS", "id": "com.palm.app.screenlock", "icon": "../images/default-app-icon.png" },
             { "title": "Oh My", "id": "com.palm.app.enyo-findapps", "icon": "../images/default-app-icon.png" },
             { "title": "Test1", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "DummyWindow", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "DummyWindow2", "id": "org.webosports.tests.dummyWindow2", "icon": "../images/default-app-icon.png" },
             { "title": "DashboardWindow", "id": "org.webosports.tests.fakeDashboardWindow", "icon": "../images/default-app-icon.png" },
             { "title": "SIMPinWindow", "id": "org.webosports.tests.fakeSimPinWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Oh My", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
             { "title": "Test No Tab", "id": "org.webosports.tests.dummyWindow", "icon": "../images/default-app-icon.png" },
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

    function getDisplayProperty_call(args, returnFct, handleError) {
        returnFct({"payload": JSON.stringify({"returnValue": true, "maximumBrightness": 70 })});
    }

    function launchApp_call(jsonArgs, returnFct, handleError) {
        // The JSON params can contain "id" (string) and "params" (object)
        if( jsonArgs.id === "org.webosports.tests.dummyWindow" || jsonArgs.id === "org.webosports.tests.dummyWindow2" ) {
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
            // start a FakePopupAlertWindow
            // Simulate the attachement of a new window to the stub Wayland compositor
            compositor.createFakeWindow("FakePopupAlertWindow", jsonArgs);
        }
        else if( jsonArgs.id === "org.webosports.tests.fakeSimPinWindow" ) {
            // start a FakeSIMPinWindow
            // Simulate the attachement of a new window to the stub Wayland compositor
            compositor.createFakeWindow("FakeSIMPinWindow", jsonArgs);
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


    function setLockStatus_call(args, returnFct, handleError) {
        console.log("setLockStatus_call: arg.status = " + args.status + " currentLockStatus = " + currentLockStatus);
        if (args.status === "unlock" && currentLockStatus === "locked") {
            currentLockStatus = "unlocked";
            lockStatusSubscriber.func({payload: "{\"lockState\":\"" + currentLockStatus + "\"}"});
        }
    }

    function getDeviceLockMode_call(args, returnFct, handleError) {
        var message = {
            "returnValue": true,
            "lockMode": deviceLockMode,
            "policyState": polcyState,
            "retriesLeft": retriesLeft
        };

        returnFct({payload: JSON.stringify(message)});
    }

    function getBatteryStatusQuery_call(args, returnFct, handleError) {
        var message = {
            "returnValue": true,
            "percent_ui": 10
        };

        returnFct({payload: JSON.stringify(message)});
    }

    function matchDevicePasscode_call(args, returnFct, handleError) {
        var success = (args.passCode === configuredPasscode);

        if (retriesLeft == 0)
            success = false;

        if (!success) {
            if (retriesLeft == 0) {
                /* FIXME */
            }
            else
                retriesLeft = retriesLeft - 1;
        }

        var message = {
            returnValue: success,
            retriesLeft: retriesLeft,
            lockedOut: false
        };

        returnFct({payload: JSON.stringify(message)});
    }
}
