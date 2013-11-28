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

    property real defaultWindowWidth: Settings.displayWidth
    property real defaultWindowHeight: Settings.displayHeight

    property real cornerRadius: 20

    signal requestPreviousState(Item windowWrapper)

    signal switchToDashboard
    signal switchToCardView
    signal switchToMaximize(Item windowWrapper)
    signal switchToFullscreen(Item windowWrapper)
    signal switchToLauncherView

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
        // The actual model item will be removed once windowRemoved is called from the
        // compositor
        if( windowWrapper.wrappedWindow )
        {
            // the wrapped window still exists, let's do it the smooth way
            compositorInstance.closeWindowWithId(windowWrapper.wrappedWindow.winId);
        }
        else
        {
            // emergency destruction: the wrapped window has already
            // been destroyed: clean up the mess
            var index = listWindowWrappersModel.getIndexFromProperty('windowWrapper', windowWrapper);
            if( index >= 0 )
            {
                var winId = listWindowWrappersModel.get(index).winId;

                if( currentActiveWindowWrapper === windowWrapper )
                    currentActiveWindowWrapper = null;

                listWindowWrappersModel.remove(index);

                windowWrapperDestruction(windowWrapper, winId);

                windowWrapper.destroy();
            }
        }
    }

    function setWindowAsActive(windowWrapper) {
        if( currentActiveWindowWrapper === windowWrapper ) return;

        if( currentActiveWindowWrapper )
            __setToCard(currentActiveWindowWrapper);

        currentActiveWindowWrapper = windowWrapper;
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
            listWindowWrappersModel.append({"windowWrapper": windowWrapper, "winId": winId});

            // emit the signal
            windowWrapperCreated(windowWrapper, winId);
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
                    currentActiveWindowWrapper = null;

                listWindowWrappersModel.remove(index);

                windowWrapperDestruction(windowWrapper, window.winId);

                windowWrapper.destroy();
            }
        }
        else {
            console.log("WindowManager: removing overlay window : " + window);
            overlayWindowRemoval(window);
        }
    }

    function __handleWindowShown(window) {
        if( window.windowType !== WindowType.Overlay ) {
        }
    }

    function __handleWindowHidden(window) {
        if( window.windowType !== WindowType.Overlay ) {
        }
    }

    function __setToMaximized(windowWrapper) {
        // switch the state to maximized
        windowWrapper.setNewParent(maximizedWindowWrapperContainer, false);

        currentActiveWindowWrapper = windowWrapper;
        windowWrapper.windowState = WindowState.Maximized;
    }
    function __setToFullscreen(windowWrapper) {
        // switch the state to fullscreen
        windowWrapper.setNewParent(fullscreenWindowWrapperContainer, false);

        currentActiveWindowWrapper = windowWrapper;
        windowWrapper.windowState = WindowState.Fullscreen;
    }
    function __setToCard(windowWrapper) {
        // switch the state to card
        windowWrapper.setNewParent(windowWrapper.cardViewParent, true);
        windowWrapper.windowState = WindowState.Carded;
    }
}
