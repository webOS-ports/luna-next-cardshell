/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LunaNext 0.1

import "../Utils"

import "WindowManagerServices.js" as WindowManagerServices

Item {
    id: windowManager

    property Item gestureAreaInstance
    property Item statusBarInstance
    property Item dashboardInstance
    property Item launcherInstance
    property QtObject compositorInstance

    property Item currentActiveWindowWrapper

    property real defaultWindowWidth: maximizedWindowWrapperContainer.width
    property real defaultWindowHeight: maximizedWindowWrapperContainer.height

    property real cornerRadius: 20

    signal requestPreviousState(Item windowWrapper)

    signal switchToDashboard
    signal switchToCardView
    signal switchToMaximize(Item windowWrapper)
    signal switchToFullscreen(Item windowWrapper)
    signal switchToLauncherView

    signal activeWindowChanged

    signal windowWrapperCreated(Item windowWrapper, int winId);
    signal windowWrapperDestruction(Item windowWrapper, int winId);

    signal overlayWindowAdded(Item window);
    signal overlayWindowRemoval(Item window);

    ExtendedListModel {
        // This model contains the list of the window wrappers that are managed by the
        // window manager.
        // Each window wrapper is a "WindowWrapper", whose child is the app's window.
        // It has only one property: "windowWrapper", of type variant
        id: listWindowWrappersModel
    }

    // maximized window container
    Item {
        id: maximizedWindowWrapperContainer

        anchors.top: statusBarInstance.bottom
        anchors.bottom: dashboardInstance.top
        anchors.left: windowManager.left
        anchors.right: windowManager.right

        z: 2
    }

    // fullscreen window container
    Item {
        id: fullscreenWindowWrapperContainer

        anchors.top: windowManager.top
        anchors.bottom: gestureAreaInstance.top
        anchors.left: windowManager.left
        anchors.right: windowManager.right

        z: 3 // in front of everything
    }

    states: [
        State {
            name: "dashboard"
            StateChangeScript {
                script: {
                    if( currentActiveWindowWrapper )
                        __setToCard(currentActiveWindowWrapper);
                    switchToDashboard();
                }
            }
        },
        State {
            name: "cardview"
            StateChangeScript {
                script: {
                    // we're back to card view so no card should have the focus
                    // for the keyboard anymore
                    if( compositorInstance )
                        compositorInstance.clearKeyboardFocus();

                    if( currentActiveWindowWrapper )
                        __setToCard(currentActiveWindowWrapper);
                    switchToCardView();
                }
            }
        },
        State {
            name: "launcherview"
            StateChangeScript {
                script: {
                    if( currentActiveWindowWrapper )
                        __setToCard(currentActiveWindowWrapper);
                    switchToLauncherView();
                }
            }
        },
        State {
            name: "maximized"
            StateChangeScript {
                script: {
                    if( currentActiveWindowWrapper )
                        __setToMaximized(currentActiveWindowWrapper);
                    switchToMaximize(currentActiveWindowWrapper);
                }
            }
        },
        State {
            name: "fullscreen"
            StateChangeScript {
                script: {
                    if( currentActiveWindowWrapper )
                        __setToFullscreen(currentActiveWindowWrapper);
                    switchToFullscreen(currentActiveWindowWrapper);
                }
            }
        }
    ]

    Connections {
        target: compositorInstance
        onWindowAdded: __handleWindowAdded(window)
        onWindowRemoved: __handleWindowRemoved(window)
        onWindowShown: __handleWindowShown(window)
        onWindowHidden: __handleWindowHidden(window)
    }

    Connections {
        target: launcherInstance
        onLauncherActiveChanged: {
            if( launcherInstance.launcherActive && state != "launcherview" )
            {
                state = "launcherview";
            }
            else if( !launcherInstance.launcherActive && state === "launcherview" )
            {
                state = "cardview"
            }
        }
    }

    Connections {
        target: gestureAreaInstance
        onTapGesture: {
                if( WindowManagerServices.nbRegisteredTapActions() > 0 ) {
                    WindowManagerServices.doNextTapAction();
                }
                else {
                    if( state !== "cardview" ) {
                        state = "cardview";
                    }
                    else if( currentActiveWindowWrapper ) {
                        state = "maximized";
                    }
                }
        }
        onSwipeUpGesture:{
            while( WindowManagerServices.nbRegisteredTapActions() > 0 ) {
                WindowManagerServices.doNextTapAction();
            }
            if( state !== "cardview" ) {
                state = "cardview";
            }
            else {
                state = "launcherview";
            }
        }
        onSwipeLeftGesture:{
            if( state === "launcherview" ) {
                state = "cardview"
            }
            else if( currentActiveWindowWrapper )
                currentActiveWindowWrapper.postEvent(EventType.CoreNaviBack);
        }
        onSwipeRightGesture:{
            if( currentActiveWindowWrapper )
                currentActiveWindowWrapper.postEvent(EventType.CoreNaviNext);
        }
    }

    Component.onCompleted: state = "cardview";


    function removeWindow(windowWrapper) {
        if( windowWrapper.aboutToBeDestroyed ) return;

        // The actual model item will be removed once windowRemoved is called from the
        // compositor
        if( windowWrapper && windowWrapper.wrappedWindow )
        {
            // the wrapped window still exists, let's do it the smooth way
            console.log("WindowManager.removeWindow(" + windowWrapper +"): calling closeWindowWithId(" + windowWrapper.wrappedWindow.winId + ")");
            compositorInstance.closeWindowWithId(windowWrapper.wrappedWindow.winId);
        }
        else if( windowWrapper )
        {
            console.log("WindowManager.removeWindow: cleaning up windowWrapper which has lost its wrapped window.");
            // emergency destruction: the wrapped window has already
            // been destroyed: clean up the mess
            var index = listWindowWrappersModel.getIndexFromProperty('windowWrapper', windowWrapper);
            if( index >= 0 )
            {
                var winId = listWindowWrappersModel.get(index).winId;

                if( currentActiveWindowWrapper === windowWrapper )
                    __setCurrentActiveWindowWrapper(null);

                listWindowWrappersModel.remove(index);

                windowWrapperDestruction(windowWrapper, winId);

                windowWrapper.requestDestruction();
            }
        }
    }

    function setWindowAsActive(windowWrapper) {
        if( currentActiveWindowWrapper === windowWrapper ) return;

        if( currentActiveWindowWrapper )
            __setToCard(currentActiveWindowWrapper);

        __setCurrentActiveWindowWrapper(windowWrapper);
        if( state === "maximized" ) {
            __setToMaximized(windowWrapper);
        }
        else if( state === "fullscreen" ) {
            __setToFullscreen(windowWrapper);
        }
    }

    function nbRegisteredTapActions() {
        return WindowManagerServices.nbRegisteredTapActions();
    }

    function addTapAction(actionID, actionFct, actionData) {
        return WindowManagerServices.addTapAction(actionID, actionFct, actionData);
    }

    function removeTapAction(actionID) {
        return WindowManagerServices.removeTapAction(actionID);
    }

    function doNextTapAction() {
        return WindowManagerServices.doNextTapAction();
    }

    function cardViewMode() {
            state = "cardview";
    }

    function maximizedMode() {
        if( currentActiveWindowWrapper )
            state = "maximized";
    }

    function fullscreenMode() {
        if( currentActiveWindowWrapper )
            state = "fullscreen";
    }

    function dashboardMode() {
            state = "dashboard";
    }

    function expandedLauncherMode() {
            state = "launcherview";
    }

    function focusApplication(appId) {
        if (typeof appId === 'undefined' || appId.length === 0)
            return false;

        /* Focusing the launcher app isn't possible as it's not handled like other
         * windows so we have to reject this here. One case where this will happen
         * is when the app menu for the launcher app should be shown but in that case
         * the launcher app should already have the focus so nothing left to for us */
        if (appId === "com.palm.launcher")
            return false;

        var index = listWindowWrappersModel.getIndexFromProperty("appId", appId);
        if (index < 0)
            return false;

        var windowWrapper = listWindowWrappersModel.get(index);
        setWindowAsActive(windowWrapper.windowWrapper);
        maximizedMode();
        return true;
    }

    function getAppIdForFocusApplication() {
        if (!currentActiveWindowWrapper)
            return null;
        return currentActiveWindowWrapper.wrappedWindow.appId;
    }

    ////// private methods ///////

    function __handleWindowAdded(window) {
        if( window.windowType !== WindowType.Overlay ) {
            // Create the window container
            var windowWrapperComponent = Qt.createComponent("WindowWrapper.qml");
            var windowWrapper = windowWrapperComponent.createObject(windowManager, {"x": gestureAreaInstance.x + gestureAreaInstance.width/2, "y": gestureAreaInstance.y});
            windowWrapper.windowManager = windowManager;
            windowWrapper.cornerRadius = cornerRadius

            // Bind the container with its app window
            windowWrapper.setWrappedWindow(window);

            var winId = window.winId;
            var appId = window.appId;
            listWindowWrappersModel.append({"windowWrapper": windowWrapper, "winId": winId, "appId": appId});

            if( window.appId === "com.palm.launcher" ) {
                // init the launcher
                launcherInstance.initJustTypeLauncherApp(windowWrapper, winId);
            }
            else {
                // emit the signal
                windowWrapperCreated(windowWrapper, winId);
            }
        }
        else {
            console.log("WindowManager: adding overlay window : " + window);
            overlayWindowAdded(window);
        }
    }

    function __handleWindowRemoved(window) {
        if( window.windowType !== WindowType.Overlay ) {
            var index = listWindowWrappersModel.getIndexFromProperty('winId', window.winId);
            if( index >= 0 )
            {
                var windowWrapper = listWindowWrappersModel.get(index).windowWrapper;

                if( currentActiveWindowWrapper === windowWrapper )
                    __setCurrentActiveWindowWrapper(null);

                listWindowWrappersModel.remove(index);

                windowWrapperDestruction(windowWrapper, window.winId);

                windowWrapper.requestDestruction();
            }
        }
        else {
            console.log("WindowManager: removing overlay window : " + window);
            overlayWindowRemoval(window);
        }
    }

    function __handleWindowShown(window) {
        if( window && window.windowType !== WindowType.Overlay ) {
        }
    }

    function __handleWindowHidden(window) {
        if( window && window.windowType !== WindowType.Overlay ) {
        }
    }

    function __setToMaximized(windowWrapper) {
        // switch the state to maximized
        windowWrapper.setNewParent(maximizedWindowWrapperContainer, false);
        if( !!windowWrapper.wrappedWindow )
            windowWrapper.wrappedWindow.changeSize(Qt.size(maximizedWindowWrapperContainer.width, maximizedWindowWrapperContainer.height));

        currentActiveWindowWrapper = windowWrapper;
        windowWrapper.windowState = WindowState.Maximized;
        activeWindowChanged();
        windowWrapper.takeFocus();
    }
    function __setToFullscreen(windowWrapper) {
        // switch the state to fullscreen
        windowWrapper.setNewParent(fullscreenWindowWrapperContainer, false);
        if( !!windowWrapper.wrappedWindow )
            windowWrapper.wrappedWindow.changeSize(Qt.size(fullscreenWindowWrapperContainer.width, fullscreenWindowWrapperContainer.height));

        currentActiveWindowWrapper = windowWrapper;
        windowWrapper.windowState = WindowState.Fullscreen;
        activeWindowChanged();
        windowWrapper.takeFocus();
    }
    function __setToCard(windowWrapper) {
        // switch the state to card
        windowWrapper.setNewParent(windowWrapper.cardViewParent, true);
        windowWrapper.windowState = WindowState.Carded;
        activeWindowChanged();
        windowWrapper.loseFocus();
    }

    function __setCurrentActiveWindowWrapper(windowWrapper) {
        currentActiveWindowWrapper = windowWrapper;
        activeWindowChanged();
    }
}
