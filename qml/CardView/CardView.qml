import QtQuick 2.0
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

import "../Utils"
import "../DockMode"
import "../WindowStateStub.js" as WindowState

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
        surfaceSource: compositorInstance.surfaceModel
        windowType: "_WEBOS_WINDOW_TYPE_CARD"
        // Same exclusion as CardGroupModel: a window exhibition mode is
        // hosting is not a card.
        acceptFunction: "acceptCard"

        function acceptCard(surfaceItem) {
            return surfaceItem.type === "_WEBOS_WINDOW_TYPE_CARD" &&
                   !ExhibitionState.isExhibitionWindow(surfaceItem);
        }

        property int exhibitionRevision: ExhibitionState.revision
        onExhibitionRevisionChanged: {
            cardsModel.locked = true;
            cardsModel.locked = false;
        }

        onRowsAboutToBeRemoved: (index, first, last) => {
            if( !cardViewItem.keepCurrentCardMaximized &&
                cardsModel.get(last).userData.windowState !== WindowState.Carded ) cardViewItem.setCurrentCardState(WindowState.Carded);
        }
    }

    CardGroupListView {
        id: cardGroupListViewInstance

        anchors.fill: cardViewItem
        maximizedCardTopMargin: cardViewItem.maximizedCardTopMargin
        isCardedViewActive: cardViewItem.state === "cardList"

        onCardRemove: (window) => { cardViewItem.removeCard(window); }
        onCardSelect: (window) => {
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
        console.log("CardView.removeCard(" + window +"): calling closeWindow");
        compositorInstance.closeWindow(window);
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
        if( !lCurrentActiveWindow ) {
            // no active window, force return to card view
            windowManagerInstance.switchToCardView();
            return;
        }

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

    // The lockscreen is transparent in the middle, so the card view must stay
    // hidden while the screen is locked even if a card is opened, focused or
    // closed in the meantime; on unlock the lockscreen replays the last
    // switchTo* signal, which makes the card view visible again.
    function __showCardView() {
        cardViewItem.visible = !windowManagerInstance.isScreenLocked();
    }

    Connections {
        target: windowManagerInstance
        function onSwitchToMaximize(window) {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "maximizedCard"
            __showCardView();
        }
        function onSwitchToFullscreen(window) {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "fullscreenCard"
            __showCardView();
        }
        function onSwitchToCardView() {
            gestureAreaConnections.target = gestureAreaInstance
            cardViewItem.state = "cardList"
            __showCardView();
        }
        function onSwitchToLauncherView() {
            gestureAreaConnections.target = null
            cardViewItem.state = "cardList"
            __showCardView();
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
                var seat = compositor.defaultSeat
                seat.sendKeyEvent(Qt.Key_Escape, true);
                seat.sendKeyEvent(Qt.Key_Escape, false);
            }
        }
        /*
        function onSwipeRightGesture(modifiers) {
            if( cardViewItem.isCurrentCardActive() ) {
                var seat = compositor.defaultSeat
                // 0xE0E3 comes from https://github.com/webOS-ports/luna-next/blob/master/plugins/compositor/eventtype.cpp#L33
                seat.sendKeyEvent(0xE0E3, true);
                seat.sendKeyEvent(0xE0E3, false);
            }
        }
        */
    }

    ///////// private section //////////
    Connections {
        target: compositorInstance
        function onSurfaceMapped(window) {
            __handleWindowAdded(window);
        }
//        function onWindowRaised(window) {
//            cardViewItem.setCurrentCard(window);
//            cardViewItem.setCurrentCardState(WindowState.Maximized);
//        }
        function onSurfaceUnmapped(window) {
            __handleWindowRemoved(window);
        }
    }

    function __handleWindowAdded(window) {
        if( window.type === "_WEBOS_WINDOW_TYPE_CARD" ) {
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
        if( window.type === "_WEBOS_WINDOW_TYPE_CARD" ) {
            var windowWrapper = window.userData;
            if( !!windowWrapper ) {
                windowWrapper.setWrappedWindow(null);
                windowWrapper.destroy();
            }
        }
    }

    // Tell the client which state its window is in.
    //
    // WindowState here is this shell's own enum and lives entirely in QML;
    // setting it moves the card and says nothing to the application. The
    // surface item carries a separate Qt::WindowState that does reach the
    // client - WebAppWayland::StateChanged() turns it into OnStageActivated or
    // OnStageDeactivated, which is where Enyo's onWindowActivated,
    // onWindowDeactivated, onWindowShown and onWindowHidden come from
    // (luneos-testing#13).
    //
    // Minimized also means "off screen" to WAM, which suspends the page for it,
    // and a suspended card paints nothing. WAM is told once, for this shell as
    // a whole, that a deactivated window stays on screen -
    // WAM_SHELL_KEEPS_DEACTIVATED_WINDOWS_SHOWN in webapp-mgr.sh - so nothing
    // has to be arranged per window here.
    //
    // Saying it per window was tried and does not work: the state is also
    // written by WebOSCompositorBase/views/FullscreenView.qml, so a window can
    // be minimized by a path this shell never sees, and the appId a per-window
    // call needs arrives asynchronously, after a window can already have been
    // deactivated. Every ordering left a card that was still on screen with a
    // suspended page behind it.
    function __publishWindowState(window, state) {
        if (!window || typeof window.state === "undefined")
            return;
        if (window.state !== state)
            window.state = state;
    }

    function __setToMaximized(window) {
        // set the card as the active one
        __setCurrentActiveWindow(window);
        window.userData.takeFocus();

        // switch the state to maximized
        window.userData.windowState = WindowState.Maximized;
        __publishWindowState(window, Qt.WindowMaximized);
        if( !!window )
            window.changeSize(Qt.size(cardViewItem.width, cardViewItem.height - maximizedCardTopMargin));
    }
    function __setToFullscreen(window) {
        // set the card as the active one
        __setCurrentActiveWindow(window);
        window.userData.takeFocus();

        // switch the state to fullscreen
        window.userData.windowState = WindowState.Fullscreen;
        __publishWindowState(window, Qt.WindowFullScreen);
        if( !!window )
            window.changeSize(Qt.size(cardViewItem.width, cardViewItem.height));
    }
    function __setToCard(window) {
        // switch the state to card
        window.userData.loseFocus();
        window.userData.windowState = WindowState.Carded;
        // Carded is Minimized to the client: it no longer holds the stage. It
        // is still on screen in the card view, hence the true.
        __publishWindowState(window, Qt.WindowMinimized);
    }

    function __setCurrentActiveWindow(window) {
        cardGroupListViewInstance.setCurrentActiveWindow(window);
    }
}
