import QtQuick 2.0
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardViewItem

    property QtObject compositorInstance
    property Item gestureAreaInstance
    property Item windowManagerInstance

    property real maximizedCardTopMargin;
    property real defaultWindowWidth: cardViewItem.width
    property real defaultWindowHeight: cardViewItem.height - maximizedCardTopMargin

    property real cornerRadius: 20

    signal currentCardChanged(Item currentCard);

    focus: true
    Keys.forwardTo: cardListViewInstance

    WindowModel {
        id: cardsModel
        windowTypeFilter: WindowType.Card
    }

    CardListView {
        id: cardListViewInstance

        cardView: cardViewItem
        anchors.fill: cardViewItem
        maximizedCardTopMargin: cardViewItem.maximizedCardTopMargin

        onCardRemove: cardViewItem.removeCard(window);
        onCardSelect: {
            cardViewItem.state = "maximizedCard";
        }
    }

    function currentActiveWindow() {
        return cardListViewInstance.currentActiveWindow();
    }

    function isCurrentCardActive() {
        var lCurrentActiveWindow = cardListViewInstance.currentActiveWindow();

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
        if( !currentActiveWindow() ) return;

        if( windowState === WindowState.Carded ) {
            state = "cardList";
        }
        else if( windowState === WindowState.Maximized ) {
            state = "maximizedCard";
        }
        else if( state === WindowState.Fullscreen ) {
            state = "fullscreenCard";
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

        var window=null;
        var i=0;
        for(i=0; i<cardsModel.count;i++) {
            window = cardsModel.getByIndex(i)
            if(window && window.appdId === appId) {
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

    state: "cardList"
    states: [
        State {
            name: "cardList";
            PropertyChanges { target: cardListViewInstance; interactiveList: true }
            StateChangeScript {
                script: {
                    var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
                    if( lCurrentActiveWindow )
                        __setToCard(lCurrentActiveWindow);

                    windowManagerInstance.switchToCardView();
                }
            }
        },
        State {
            name: "maximizedCard";
            PropertyChanges { target: cardListViewInstance; interactiveList: false }
            StateChangeScript {
                script: {
                    var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
                    if( lCurrentActiveWindow ) {
                        __setToMaximized(lCurrentActiveWindow);

                        windowManagerInstance.switchToMaximize(lCurrentActiveWindow);
                    }
                }
            }
        },
        State {
            name: "fullscreenCard";
            PropertyChanges { target: cardListViewInstance; interactiveList: false }
            StateChangeScript {
                script: {
                    var lCurrentActiveWindow = cardViewItem.currentActiveWindow();
                    if( lCurrentActiveWindow ) {
                        __setToFullscreen(lCurrentActiveWindow);

                        windowManagerInstance.switchToFullscreen(lCurrentActiveWindow);
                    }
                }
            }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            gestureAreaConnections.target = gestureAreaInstance
        }
        onSwitchToMaximize: {
            gestureAreaConnections.target = gestureAreaInstance
        }
        onSwitchToFullscreen: {
            gestureAreaConnections.target = gestureAreaInstance
        }
        onSwitchToCardView: {
            gestureAreaConnections.target = gestureAreaInstance
        }
        onSwitchToLauncherView: {
            gestureAreaConnections.target = null
        }
    }

    ///////// gesture area management ///////////
    Connections {
        id: gestureAreaConnections
        target: gestureAreaInstance
        onTapGesture: {
            if( cardViewItem.isCurrentCardActive() ) {
                cardViewItem.setCurrentCardState(WindowState.Carded);
            }
            else {
                cardViewItem.setCurrentCardState(WindowState.Maximized);
            }
        }
        onSwipeUpGesture:{
            if( cardViewItem.isCurrentCardActive() ) {
                cardViewItem.setCurrentCardState(WindowState.Carded);
            }
        }
        onSwipeLeftGesture:{
            if( cardViewItem.isCurrentCardActive() )
                cardViewItem.currentActiveWindow().postEvent(EventType.CoreNaviBack);
        }
        onSwipeRightGesture:{
            if( cardViewItem.isCurrentCardActive() )
                cardViewItem.currentActiveWindow().postEvent(EventType.CoreNaviNext);
        }
    }

    ///////// private section //////////
    Connections {
        target: compositorInstance
        onWindowAdded: __handleWindowAdded(window)
        onWindowRemoved: __handleWindowRemoved(window)
    }

    function __handleWindowAdded(window) {
        if( window.windowType === WindowType.Card ) {
            // Create the window container
            var windowWrapperComponent = Qt.createComponent("CardWindowWrapper.qml");
            var windowWrapper = windowWrapperComponent.createObject(cardViewItem, {"x": gestureAreaInstance.x + gestureAreaInstance.width/2, "y": gestureAreaInstance.y});
            windowWrapper.cardView = cardViewItem;
            windowWrapper.cornerRadius = cornerRadius

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
        cardListViewInstance.setCurrentActiveWindow(window);
    }
}
