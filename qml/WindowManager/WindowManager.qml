import QtQuick 2.0
import LunaNext 0.1

Item {
    id: windowManager

    property Item gestureAreaInstance
    property Item statusBarInstance
    property Item dashboardInstance

    property Item currentActiveWindowWrapper

    property real cornerRadius: 20

    signal requestPreviousState(Item windowWrapper)
    signal expandLauncher

    signal switchToDashboard
    signal switchToCardView
    signal switchToMaximize(Item windowWrapper)
    signal switchToFullscreen(Item windowWrapper)

    signal windowWrapperCreated(Item windowWrapper, int winId);
    signal windowWrapperDestruction(Item windowWrapper, int winId);

    ListModel {
        // This model contains the list of the window wrappers that are managed by the
        // window manager.
        // Each window wrapper is a "WindowWrapper", whose child is the app's window.
        // It has only one property: "windowWrapper", of type variant
        id: listWindowWrappersModel

        function getIndexFromProperty(modelProperty, propertyValue) {
            var i=0;
            for(i=0; i<listWindowWrappersModel.count;i++) {
                var item=get(i);
                if(item && item[modelProperty] === propertyValue) {
                    return i;
                }
            }

            console.log("WindowManager: couldn't find " + modelProperty + "!");
            return -1;
        }
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
                    if( currentActiveWindowWrapper )
                        __setToCard(currentActiveWindowWrapper);
                    switchToCardView();
                }
            }
        },
        State {
            name: "fulllauncher"
            StateChangeScript {
                script: {
                    if( currentActiveWindowWrapper )
                        __setToCard(currentActiveWindowWrapper);
                    expandLauncher();
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
        target: compositor
        onWindowAdded: __handleWindowAdded(window)
        onWindowRemoved: __handleWindowRemoved(window)
    }

    Connections {
        target: gestureAreaInstance
        onTapGesture: {
                if( state !== "cardview" ) {
                    state = "cardview";
                }
                else if( currentActiveWindowWrapper ) {
                    state = "maximized";
                }
        }
        onSwipeUpGesture:{
            if( state !== "cardview" ) {
                state = "cardview";
            }
            else {
                state = "fulllauncher";
            }
        }
    }

    Component.onCompleted: state = "cardview";


    function removeWindow(windowWrapper) {
        // The actual model item will be removed once windowRemoved is called from the
        // compositor
        compositor.closeWindowWithId(windowWrapper.wrappedWindow.winId);
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

    ////// private methods ///////

    function __handleWindowAdded(window) {
        // Create the window container
        var windowWrapperComponent = Qt.createComponent("WindowWrapper.qml");
        var windowWrapper = windowWrapperComponent.createObject(windowManager);
        windowWrapper.windowManager = windowManager;
        windowWrapper.cornerRadius = cornerRadius

        // Bind the container with its app window
        windowWrapper.setWrappedWindow(window);

        var winId = window.winId;
        listWindowWrappersModel.append({"windowWrapper": windowWrapper, "winId": winId});

        // emit the signal
        windowWrapperCreated(windowWrapper, winId);
    }

    function __handleWindowRemoved(window) {
        var index = listWindowWrappersModel.getIndexFromProperty('winId', window.winId);
        if( index >= 0 )
        {
            var windowWrapper = listWindowWrappersModel.get(index).windowWrapper;

            if( currentActiveWindowWrapper === windowWrapper )
                currentActiveWindowWrapper = null;

            windowWrapperDestruction(windowWrapper, window.winId);

            listWindowWrappersModel.remove(index);
            windowWrapper.destroy();
        }
    }

    function __setToMaximized(windowWrapper) {
        // switch the state to maximized
        windowWrapper.windowState = WindowState.Maximized;
        currentActiveWindowWrapper = windowWrapper;

        windowWrapper.setNewParent(maximizedWindowWrapperContainer, false);

        if (windowWrapper.child) {
            // take focus for receiving input events
            windowWrapper.child.takeFocus();
        }

        // emit signal
        switchToMaximize(windowWrapper);
    }
    function __setToFullscreen(windowWrapper) {
        // switch the state to fullscreen
        windowWrapper.windowState = WindowState.Fullscreen;
        currentActiveWindowWrapper = windowWrapper;

        windowWrapper.setNewParent(fullscreenWindowWrapperContainer, false);

        if (windowWrapper.child) {
            // take focus for receiving input events
            windowWrapper.child.takeFocus();
        }

        // emit signal
        switchToFullscreen(windowWrapper);
    }
    function __setToCard(windowWrapper) {
        // switch the state to card
        windowWrapper.windowState = WindowState.Carded;
        windowWrapper.setNewParent(windowWrapper.cardViewParent, true);

        // we're back to card view so no card should have the focus
        // for the keyboard anymore
        if( compositor )
            compositor.clearKeyboardFocus();

        // emit signal
        switchToCardView();
    }
}
