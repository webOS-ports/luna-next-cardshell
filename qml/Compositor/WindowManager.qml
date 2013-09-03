import QtQuick 2.0
import LunaNext 0.1

Item {
    id: windowManager

    property Item gestureArea
    property Item cardView
    property Item statusBar
    property Item notificationsContainer

    property Item currentActiveWindowWrapper

    property real cornerRadius: 40

    property alias maximizedwindowWrapperContainer: maximizedWindowWrapperContainer
    property alias fullscreenwindowWrapperContainer: fullscreenWindowWrapperContainer

    signal switchToMaximize(Item windowWrapper)
    signal switchToFullscreen(Item windowWrapper)
    signal switchToCard(Item windowWrapper)

    QtObject {
        id: localProperties

        property int nextWinId: 0;

        function getNextWinId() {
            nextWinId++;
            return nextWinId;
        }
    }

    signal windowWrapperCreated(Item windowWrapper, int winId);

    ListModel {
        // This model contains the list of the windows that are managed by the compositor.
        // Each window is actually a "windowWrapper", whose child is the app's window.
        // It has only one property: "window", of type variant
        id: listWindowWrappersModel

        function getIndexFromProperty(modelProperty, propertyValue) {
            var i=0;
            for(i=0; i<listWindowWrappersModel.count;i++) {
                var item=get(i);
                if(item && item[modelProperty] === propertyValue) {
                    return i;
                }
            }

            console.log("Couldn't find window!");
            return -1;
        }
    }

    // maximized window container
    Item {
        id: maximizedWindowWrapperContainer

        anchors.top: statusBarInstance.bottom
        anchors.bottom: notificationsContainer.top
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

    Connections {
        target: cardView
        onCardRemoved: {
            removeWindow(cardComponentInstance.windowWrapper);
        }
    }

    Connections {
        target: compositor
        onWindowAdded: handleWindowAdded(window)
        onWindowRemoved: handleWindowRemoved(window)
    }

    function handleWindowAdded(window) {
        // Create the window container
        var windowWrapperComponent = Qt.createComponent("WindowWrapper.qml");
        var windowWrapper = windowWrapperComponent.createObject(windowManager);
        windowWrapper.windowManager = windowManager;
        windowWrapper.cornerRadius = cornerRadius

        // Bind the container with its app window
        windowWrapper.setWrappedWindow(window);

        var winId = window.id;
        listWindowWrappersModel.append({"windowWrapper": windowWrapper, "winId": winId});

        // emit the signal
        windowWrapperCreated(windowWrapper, winId);
    }

    function handleWindowRemoved(window) {
        var windowWrapper = window.parent;
        var index = listWindowWrappersModel.getIndexFromProperty('window', windowWrapper);
        if( index >= 0 )
        {
            listWindowWrappersModel.remove(index);
            windowWrapper.destroy();
        }
    }

    function removeWindow(windowWrapper) {
        // The actual model item will be removed once windowRemoved is called from the
        // compositor
        compositor.closeWindowWithId(windowWrapper.wrappedWindow.appId);
    }

    function setWindowState(windowWrapper, windowState) {
        if( windowState === WindowState.Maximized ) {
            setToMaximized(windowWrapper);
        }
        else if(windowState === WindowState.Fullscreen) {
            setToFullscreen(windowWrapper);
        }
        else {
            setToCard(windowWrapper);
        }
    }

    function setToMaximized(windowWrapper) {
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
    function setToFullscreen(windowWrapper) {
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
    function setToCard(windowWrapper) {
        // switch the state to card
        windowWrapper.windowState = WindowState.Carded;
        currentActiveWindowWrapper = null;

        windowWrapper.setNewParent(windowWrapper.cardViewParent, true);

        // we're back to card view so no card should have the focus
        // for the keyboard anymore
        if( compositor )
            compositor.clearKeyboardFocus();

        // emit signal
        switchToCard(windowWrapper);
    }
}
