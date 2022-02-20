import QtQuick 2.0
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

import "../Utils"

Item {
    id: cardViewItem

    property QtObject compositorInstance
    property Item gestureAreaInstance
    property Item windowManagerInstance

    property real maximizedCardTopMargin;
    property real defaultWindowWidth: cardViewItem.width
    property real defaultWindowHeight: cardViewItem.height - maximizedCardTopMargin

    property bool keepCurrentCardMaximized: false

    property real cornerRadius: 20

    signal currentCardChanged();

    focus: true
    Keys.forwardTo: cardGroupListViewInstance

    WindowModel {
        id: cardsModel
//        windowTypeFilter: WindowType.Card

        onRowsAboutToBeRemoved: {
            if( !cardViewItem.keepCurrentCardMaximized &&
                cardsModel.getByIndex(last).userData.windowState !== WindowState.Carded ) cardViewItem.setCurrentCardState(WindowState.Carded);
        }
    }

    CardGroupListView {
        id: cardGroupListViewInstance

        anchors.fill: cardViewItem
        maximizedCardTopMargin: cardViewItem.maximizedCardTopMargin
        isCardedViewActive: cardViewItem.state === "cardList"

        onCardRemove: cardViewItem.removeCard(window);
        onCardSelect: {
            setCurrentCard(window);
            if(window.userData.isFullScreenMode) {
                setCurrentCardState(WindowState.Fullscreen);
            }
            else {
                setCurrentCardState(WindowState.Maximized);
            }
        }
        onCurrentCardChanged: {
            if( cardViewItem.keepCurrentCardMaximized ) setCurrentCardState(WindowState.Maximized);
            cardViewItem.currentCardChanged();
        }
    }

    function currentActiveWindow() {
        return cardGroupListViewInstance.currentActiveWindow();
    }

    function isCurrentCardActive() {
        var lCurrentActiveWindow = cardGroupListViewInstance.currentActiveWindow();

        return (lCurrentActiveWindow && lCurrentActiveWindow.userData &&
                lCurrentActiveWindow.userData.windowState !== WindowState.Carded);
    }

    function removeCard(window) {
        console.log("CardView.removeCard(" + window +"): calling closeWindowWithId(" + window.winId + ")");
        compositorInstance.closeWindowWithId(window.winId);
    }

    function setCurrentCard(window) {
        var lCurrentActiveWindow = currentActiveWindow();

        if( lCurrentActiveWindow === window ) return;

        // First, put the previously current card into card mode
        setCurrentCardState(WindowState.Carded);

        // Then make the change
        __setCurrentActiveWindow(window);
    }

    function setCurrentCardState(windowState) {
        var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
        if( !lCurrentActiveWindow ) return;

        if( windowState === WindowState.Carded ) {
            if( state !== "cardList" )
                windowManagerInstance.switchToCardView();
            else
                __setToCard(lCurrentActiveWindow);
        }
        else if( windowState === WindowState.Maximized ) {
            if( state !== "maximizedCard" )
                windowManagerInstance.switchToMaximize(lCurrentActiveWindow);
            else
                __setToMaximized(lCurrentActiveWindow);
        }
        else if( windowState === WindowState.Fullscreen ) {
            if( state !== "fullscreenCard" )
                windowManagerInstance.switchToFullscreen(lCurrentActiveWindow);
            else
                __setToFullscreen(lCurrentActiveWindow);
        }
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

        if (getAppIdForFocusApplication() === appId)
            return true;

        var window=null;
        var i=0;
        for(i=0; i<cardsModel.count;i++) {
            window = cardsModel.getByIndex(i)
            if(window && window.appId === appId) {
                setCurrentCard(window);
                setCurrentCardState(WindowState.Maximized);
                return true;
            }
        }

        return false;
    }

    function getAppIdForFocusApplication() {
        var lCurrentActiveWindow = currentActiveWindow();

        if (!lCurrentActiveWindow)
            return null;
        return lCurrentActiveWindow.appId;
    }

    function enableFullScreenMode(appId, enableFS) {
        var window=null;
        var i=0;
        for(i=0; i<cardsModel.count;i++) {
            window = cardsModel.getByIndex(i)
            if(window && window.appId === appId) {
                if(window.userData) {
                    window.userData.isFullScreenMode = enableFS;
                    if(window.userData.windowState === WindowState.Maximized) {
                        windowManagerInstance.switchToFullscreen(window);
                    }
                    else if(window.userData.windowState === WindowState.Fullscreen) {
                        windowManagerInstance.switchToMaximize(window);
                    }
                    return true;
                }
            }
        }

        return false;
    }

    state: "cardList"
    states: [
        State {
            name: "cardList";
            PropertyChanges { target: cardGroupListViewInstance; interactiveList: true }
            StateChangeScript {
                script: {
                    var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
                    if( lCurrentActiveWindow )
                        __setToCard(lCurrentActiveWindow);
                }
            }
        },
        State {
            name: "maximizedCard";
            PropertyChanges { target: cardGroupListViewInstance; interactiveList: false }
            StateChangeScript {
                script: {
                    var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
                    if( lCurrentActiveWindow ) {
                        __setToMaximized(lCurrentActiveWindow);
                    }
                }
            }
        },
        State {
            name: "fullscreenCard";
            PropertyChanges { target: cardGroupListViewInstance; interactiveList: false }
            StateChangeScript {
                script: {
                    var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
                    if( lCurrentActiveWindow ) {
                        __setToFullscreen(lCurrentActiveWindow);
                    }
                }
            }
        }
    ]

    Connections {
        target: windowManagerInstance
        function onSwitchToMaximize(window) {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "maximizedCard"
            cardViewItem.visible = true;
        }
        function onSwitchToFullscreen(window) {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "fullscreenCard"
            cardViewItem.visible = true;
        }
        function onSwitchToCardView() {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "cardList"
            cardViewItem.visible = true;
        }
        function onSwitchToLauncherView() {
            gestureAreaConnections.target = null
            cardViewItem.state = "cardList"
            cardViewItem.visible = true;
        }
        function onSwitchToLockscreen() {
            gestureAreaConnections.target = null
            cardViewItem.visible = false;
        }
        function onSwitchToDockMode() {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "cardList"
            cardViewItem.visible = false;
        }
    }

    ///////// gesture area management ///////////
    Connections {
        id: gestureAreaConnections
        target: gestureAreaInstance
        function onTapGesture() {
            if( 0 === windowManagerInstance.nbRegisteredTapActionsBeforeTap ) {
                if( cardViewItem.isCurrentCardActive() ) {
                    cardViewItem.setCurrentCardState(WindowState.Carded);
                }
                else {
                    cardViewItem.setCurrentCardState(WindowState.Maximized);
                }
            }
        }
        function onSwipeUpGesture(modifiers) {
            if( cardViewItem.isCurrentCardActive() ) {
                cardViewItem.setCurrentCardState(WindowState.Carded);
            }
        }
        function onSwipeLeftGesture(modifiers) {
            if( cardViewItem.isCurrentCardActive() ) {
                cardViewItem.currentActiveWindow().postEvent(EventType.CoreNaviBack);
            }
        }
        function onSwipeRightGesture(modifiers) {
            if( cardViewItem.isCurrentCardActive() ) {
                cardViewItem.currentActiveWindow().postEvent(EventType.CoreNaviNext);
            }
        }
    }

    ///////// private section //////////
    Connections {
        target: compositorInstance
        function onWindowAdded(window) {
            __handleWindowAdded(window);
        }
        function onWindowRaised(window) {
            cardViewItem.setCurrentCard(window);
            cardViewItem.setCurrentCardState(WindowState.Maximized);
        }
        function onWindowRemoved(window) {
            __handleWindowRemoved(window);
        }
    }

    function __handleWindowAdded(window) {
        if( window.windowType === WindowType.Card ) {
            // Create the window container
            var windowWrapperComponent = Qt.createComponent("CardWindowWrapper.qml");
            var windowWrapper = windowWrapperComponent.createObject(cardViewItem, {"x": gestureAreaInstance.x + gestureAreaInstance.width/2,
                                                                                   "y": gestureAreaInstance.y,
                                                                                   "cardView": cardViewItem,
                                                                                   "cornerRadius": cornerRadius});
            // Bind the container with its app window
            windowWrapper.setWrappedWindow(window);
        }
    }

    function __handleWindowRemoved(window) {
        if( window.windowType === WindowType.Card ) {
            var windowWrapper = window.userData;
            if( !!windowWrapper ) {
                windowWrapper.setWrappedWindow(null);
                windowWrapper.destroy();
            }
        }
    }

    function __setToMaximized(window) {
        // set the card as the active one
        __setCurrentActiveWindow(window);
        window.userData.takeFocus();

        // switch the state to maximized
        window.userData.windowState = WindowState.Maximized;
        if( !!window )
            window.changeSize(Qt.size(cardViewItem.width, cardViewItem.height - maximizedCardTopMargin));
    }
    function __setToFullscreen(window) {
        // set the card as the active one
        __setCurrentActiveWindow(window);
        window.userData.takeFocus();

        // switch the state to fullscreen
        window.userData.windowState = WindowState.Fullscreen;
        if( !!window )
            window.changeSize(Qt.size(cardViewItem.width, cardViewItem.height));
    }
    function __setToCard(window) {
        // switch the state to card
        window.userData.loseFocus();
        window.userData.windowState = WindowState.Carded;
    }

    function __setCurrentActiveWindow(window) {
        cardGroupListViewInstance.setCurrentActiveWindow(window);
    }
}
