/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Alan Stice <alan@alanstice.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org> 
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

import QtQuick 2.12
import LunaNext.Common 0.1
import LunaNext.Shell 0.1
import WebOSCompositorBase 1.0
import LuneOS.Components 1.0

import "CardView"
import "DockMode"
import "StatusBar"
import "LaunchBar"
import "WindowManager"
import "LunaSysAPI"
import "Utils"
import "Notifications"
import "Connectors"
import "LockScreen"
import "AppTweaks"
import "NFC"

// The window manager manages the switch between different window modes
//     (card, maximized, fullscreen, ...)
// All the card related management itself is done by the CardView component
WindowManager {
    id: windowManager

    property real screenwidth: windowManager.width
    property real screenheight: windowManager.height
    property real screenDPI: Settings.dpi

    signal showPowerMenu()

    states: [
        State {
            name: "firstuse"
            PropertyChanges { target: gestureAreaInstance; height: 0 }
            PropertyChanges { target: lockScreen; isFirstUse: true }
            PropertyChanges { target: cardViewInstance; keepCurrentCardMaximized: false }
        },
        State {
            name: "normal"
            PropertyChanges { target: gestureAreaInstance; height: Units.gu(4) }
            PropertyChanges { target: lockScreen; isFirstUse: false }
            PropertyChanges { target: cardViewInstance; keepCurrentCardMaximized: false }
        }
    ]

    gestureAreaInstance: gestureAreaInstance
    property bool gesturesEnabled: !lockScreen.locked && !dockMode.visible && state === "normal"

    //! True while an application's own window is what the screen is showing: a
    //! card of its own, with none of the shell's own UI in front of it. What the
    //! arrow keys mean depends on this - in the shell they move the launcher's
    //! selection, and in an application they are a finger on the glass.
    readonly property bool applicationForeground:
        gesturesEnabled && !launcherInstance.launcherActive &&
        (cardViewInstance.state === "maximizedCard" || cardViewInstance.state === "fullscreenCard")

    //! The window of the application in front, or null when the shell's own UI
    //! is. A function rather than a property because which card is in front
    //! changes without anything here to bind to, and whoever asks wants the
    //! answer now. Not compositor.activeSurface: that is empty for some
    //! applications - a browser_shell one, for instance - and the card view
    //! knows perfectly well what it is showing.
    function foregroundWindow() {
        return applicationForeground ? cardViewInstance.currentActiveWindow() : null;
    }
    function isScreenLocked() {
        return lockScreen.locked;
    }

    /*!
     * \brief Show or hide the full launcher.
     *
     * Exposed because the launcher is private to this component and a hardware
     * key arrives in a connector that cannot see it.
     *
     * Makes the same transition the launch bar's own button does rather than
     * setting launcherInstance.fullLauncherVisible: that property is driven by
     * the launcher's states, so writing it directly fights the state machine
     * instead of moving it.
     */
    function toggleLauncher() {
        if (lockScreen.locked)
            return;

        launcherInstance.lastHardwareKeyToggleAt = Date.now();
        launcherInstance.state =
            (launcherInstance.state === "fullLauncher") ? "launchbar" : "fullLauncher";
    }

    focus: true
    Keys.forwardTo: [ gestureAreaInstance, launcherInstance, cardViewInstance, volumeControl ]

    onSwitchToCardView: {
        // we're back to card view so no card should have the focus
        // for the keyboard anymore
    //    if( compositor )
    //        compositor.clearKeyboardFocus();
        takeKeyboardFocus();
    }

    /*!
     * \brief Take the keyboard focus for the shell itself.
     *
     * Everything the shell does with a key - Just Type, the launcher's tabs,
     * cycling through cards - happens in a Keys handler somewhere under this
     * item, and a Keys handler only ever runs for the window's active focus item
     * or one of its parents. Several things here claim that focus while they are
     * up (the lock screen's pads, an application's own surface), and when they go
     * away Qt has nobody to hand it back to: the window is left with no active
     * focus item at all. Every key then reaches the compositor, is offered to the
     * key filters - which is why the volume keys still worked - and is dropped.
     * That is what "typing does nothing" was on a shell that had just started or
     * had just been unlocked, until something on screen was tapped.
     *
     * Deliberately not while the lock screen is up: the pads read the keyboard
     * themselves, which is how a PIN typed on a hardware keyboard gets in, and
     * they take the focus back as they fade in. Taking it here would only fight
     * them.
     */
    function takeKeyboardFocus() {
        if (lockScreen.locked)
            return;

        /*
         * An application in front keeps the keyboard; the shell only takes it
         * when its own UI is what is on screen.
         *
         * Taking it regardless is worse than it sounds. The compositor hands
         * keys to whichever surface holds the keyboard focus, and it also
         * refuses a text field: WaylandTextModel::textModelActivate declines an
         * activation whose surface is not the focused one ("activation declined
         * for non-focused surface"), so an application left without the keyboard
         * focus cannot be typed into and cannot raise a keyboard at all - the
         * input method is never even told a field was focused. Unlocking with an
         * application in front is how that happened: the lock screen's pads gave
         * the focus up, this took it, and nothing gave it back until the card
         * changed state.
         */
        var foreground = foregroundWindow();
        if (foreground && foreground.userData) {
            foreground.userData.takeFocus();
            return;
        }

        windowManager.forceActiveFocus();
    }

    //! The shell starts out with the focus its QML asks for, but only if nothing
    //! claimed it later during start-up - so ask for it once everything is up.
    Component.onCompleted: windowManager.takeKeyboardFocus()

    //! And again when the lock screen goes: it was holding the keyboard, and
    //! whichever pad had it is hidden now rather than passing it on.
    Connections {
        target: lockScreen
        function onLockedChanged() {
            if (!lockScreen.locked)
                windowManager.takeKeyboardFocus();
        }
    }

    Loader {
        anchors.top: parent.top
        anchors.left: parent.left

        width: 50
        height: 32

        // always on top of everything else!
        z: 1000

        Component {
            id: fpsTextComponent
            Text {
                color: "red"
                font.pixelSize: FontUtils.sizeToPixels("medium")
                text: fpsCounter.fps + " fps"

                FpsCounter {
                    id: fpsCounter
                }
            }
        }

        sourceComponent: systemService.fpsVisible ? fpsTextComponent : null;
    }
/*
    // Component already uses an Loader internally so need to do that again here 
    PerformanceOverlay {
        id: performanceOverlay
        z: 1000
        active: false
        onActiveChanged: {
            // User can disable performance UI by clicking on it 
            if (active !== systemService.performanceUIVisible)
                systemService.performanceUIVisible = active;
        }
    }
*/

    Item {
        id: background
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        z: -1; // the background item should always be behind other components

        Image {
            id: backgroundImage

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: preferences.wallpaperFile
            asynchronous: true
            layer.mipmap: true
            sourceSize: Qt.size(screenwidth, screenheight)
        }
    }

    VolumeControl {
        id: volumeControl
    }

    ScreenShooter {
        id: screenShooter
    }

    // The camera shutter, as LunaSysMgr played it for every screen capture
    // (lunaSystemSoundScreenCapture).
    FeedbackSound {
        id: shutterSound
        soundName: "shutter"
    }

    ScreenShooterGradient {
        id: screenShooterGradient
        anchors.fill: parent
        z: 11
    }

    // Legacy webOS's Touch to Share ripple, ported to trigger on real NFC
    // tag presence instead
    NfcGlow {
        id: nfcGlowInstance
        anchors.fill: parent
        z: 11
    }

    // Acts on a scanned tag's content (open a link, call a number, ...)
    NfcAutoDispatch {
        id: nfcAutoDispatchInstance
    }

    Connections {
        target: gestureAreaInstance
        function onSwipeRightGesture(modifiers) {
            shutterSound.play();
            screenShooter.capture("");
            screenShooterGradient.startShootEffect();
        }
    }

    Connections {
        target: gestureHandlerInstance
        function onScreenEdgeFlickEdgeBottom(timeout, pos) {
            if (!timeout && gestureAreaInstance.visible === false
                    && gesturesEnabled === true)
                gestureAreaInstance.swipeUpGesture(0);
        }
    }

    // luna-surfacemanager turns a client's wl_webos_shell_surface set_state into
    // fullscreenRequested() on the compositor (via WebOSSurfaceItem::
    // requestStateChange -> requestFullscreen). Nothing here was connected to
    // it, so "launch" of an app that is already running went as far as
    // WebAppWayland::Raise() in WAM, crossed Wayland, and then stopped - the
    // launch reported success and the card stayed where it was.
    //
    // focusApplication() is exactly the right response and already exists; it
    // was simply unreachable except over luna-service, which is why the
    // com.palm.systemmanager/focusApplication path worked while launch did not.
    //
    // minimizeRequested() is deliberately left alone: the card shell decides
    // for itself when a card goes back to the stack, and honouring a client's
    // minimize here would fight that.
    Connections {
        target: compositor

        function onFullscreenRequested(item) {
            if (item)
                cardViewInstance.focusApplication(item.appId);
        }
    }

    SystemService {
        id: systemService
        cardViewInstance: cardViewInstance
        compositorInstance: compositor

        onPerformanceUIVisibleChanged: {
            performanceOverlay.active = performanceUIVisible;
        }
    }

    CardView {
        id: cardViewInstance

        compositorInstance: compositor
        gestureAreaInstance: gestureAreaInstance
        windowManagerInstance: windowManager

        maximizedCardTopMargin: cardViewInstance.state === "fullscreenCard" ? 0 : statusBarInstance.y + statusBarInstance.height

        anchors.top: parent.top
        anchors.bottom: cardViewInstance.state === "fullscreenCard" ? notificationAreaInstance.bottom : notificationAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        onStateChanged: {
            if( cardViewInstance.state === "cardList" ) {
                cardViewInstance.z = 0;   // cardlist under all the rest
            }
            else if( cardViewInstance.state === "maximizedCard" ) {
                cardViewInstance.z = 2;   // active card over justtype and launcher, under dashboard and statusbar
            }
            else {
                cardViewInstance.z = 3;   // active card over everything
            }
        }
    }

    Launcher {
        id: launcherInstance

        gestureAreaInstance: gestureAreaInstance
        windowManagerInstance: parent

        anchors.top: statusBarInstance.bottom
        anchors.bottom: notificationAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        // Sat behind the lock screen purely on z-order (1 vs LockScreen's
        // 700) before this - fine as long as the lock screen's own visuals
        // are fully opaque everywhere, which is apparently not always true
        // (intermittently visible behind the padlock screen). Hidden
        // outright instead, the same defensive way notificationAreaInstance
        // right below already is.
        visible: !lockScreen.visible

        z: 1 // on top of cardview when no card is active
    }

    Loader {
        id: notificationAreaInstance

        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible

        z: 2 // on top of cardview when no card is active

        Component.onCompleted: if (!Settings.tabletUi) {
            notificationAreaInstance.setSource("Notifications/NotificationArea.qml",
                      {"compositorInstance": compositor,
                       "windowManagerInstance": parent,
                       "maxDashboardWindowHeight": Qt.binding(() => {return windowManager.height/2;})});
        }
    }

    // While an alert is up, a press anywhere outside it closes it, as a tap
    // on the gesture area already did; until now tapping elsewhere left it
    // sitting there. The press is taken, so what is underneath does not also
    // react to a tap that only meant "go away". It sits just under the alert
    // area and exists only while there is an alert.
    MouseArea {
        id: alertDismissArea

        anchors.fill: parent
        z: 3

        enabled: alertWindowsAreaInstance.visible && alertWindowsAreaInstance.maxHeight > 0
        visible: enabled

        onPressed: alertWindowsAreaInstance.closeAll()
    }

    AlertWindowsArea {
        id: alertWindowsAreaInstance

        /* Phone ui gives alerts a full width bar resting on the notification
         * area. Tablet ui floats them instead, in a panel hanging from the top
         * right corner under the status bar - that is where LunaSysMgr put them
         * too: positionAlertWindowContainer() placed a container
         * kTabletNotificationContentWidth (320) wide against the top right of
         * the positive space. The inset is measured off webOS 3.0.5 on a
         * touchpad rather than taken from kTabletAlertWindowPadding (5), since
         * that 5 was on top of the transparent border baked into the popup
         * background image, which the panel drawn here does not have.
         */
        readonly property real tabletInset: Units.length(14)

        anchors.top: Settings.tabletUi ? statusBarInstance.bottom : undefined
        anchors.topMargin: Settings.tabletUi ? tabletInset : 0
        anchors.bottom: Settings.tabletUi ? undefined
                                          : (gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom)

        // Placed outright rather than anchored horizontally, so the two layouts
        // do not have to hand a left anchor back and forth. The width is the
        // alert itself plus the panel margin it sits in.
        width: Settings.tabletUi ? Units.length(320) + 2 * contentMargin : parent.width
        x: Settings.tabletUi ? parent.width - width - tabletInset : 0

        visible: !lockScreen.visible
        windowManagerItem: windowManager
        compositorInstance: compositor

        z: 4 // just under the keyboard
    }

    KeyboardOverlay {
        id: overlaysManagerInstance

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible || lockScreen.needKeyboard
        compositorInstance: compositor

        z: 4 // on top of everything (including fullscreen)
    }

    DockMode {
        id: dockMode

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        windowManagerInstance: windowManager
        compositorInstance: compositor

        z: 5 // fullscreen window, above keyboard
    }

    SIMPinWindowArea {
        id: simPinWindowArea

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        windowManagerInstance: windowManager
        compositorInstance: compositor

        visible: !lockScreen.visible && simPinWindowArea.simPinWindowPresent

        z: 5 // fullscreen window, above keyboard
    }

    LockScreen {
        id: lockScreen

        z: 700

        windowManagerInstance: windowManager

        isFirstUse: false

        anchors.top: statusBarInstance.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    /*! The shell's own Select All/Cut/Copy/Paste overlay.
     *
     * Fills the card area rather than sitting inside the status bar, because
     * the pill has to be able to appear over the application and a press
     * anywhere outside it has to dismiss it.
     */
    EditOverlay {
        id: editOverlay

        anchors.fill: parent
        compositorInstance: compositor
        foregroundWindow: windowManager.foregroundWindow
        // Just Type is an application too, shown by the launcher rather than
        // the card view, so it is not covered by applicationForeground.
        applicationForeground: windowManager.applicationForeground ||
                               (!lockScreen.locked && launcherInstance.justTypeLauncherActive)

        keyboardService: KeyboardService {}
    }

    /*!
     * \brief A long press on the text is what asks for that pill.
     *
     * Where the hand expects it, and where legacy's selection pill came from -
     * not a long press on the application's title in the status bar, which
     * nobody would think to try.
     *
     * The press is only watched, never taken: a PointHandler holds a passive
     * grab, so the touch still reaches the application underneath and whatever
     * it does with a long press of its own is unchanged. And it is only watched
     * at all while a text field holds the input method's focus - the same
     * condition the pill is shown under - because otherwise every long press in
     * every application would be a question about pasting.
     */
    Item {
        anchors.fill: parent
        z: 1000 // under the pill itself, over the cards

        enabled: editOverlay.editable && !editOverlay.visible

        PointHandler {
            id: editPressMonitor

            //! Where the finger went down, to tell a hold from a drag.
            property point pressedAt

            //! Whether there was a selection under the finger as it went down.
            property bool selectedAtPress: false

            onActiveChanged: {
                if (editPressMonitor.active) {
                    editPressMonitor.pressedAt = editPressMonitor.point.position;
                    editPressMonitor.selectedAtPress = editOverlay.hasSelection;
                    editTapTimer.stop();
                    spellingTapTimer.stop();
                    editPressTimer.restart();
                } else {
                    // The hold timer still running means the finger neither
                    // moved off nor stayed down long enough: that was a tap.
                    var wasTap = editPressTimer.running;
                    editPressTimer.stop();

                    if (wasTap && editPressMonitor.selectedAtPress)
                        editTapTimer.restart();
                    else if (wasTap)
                        spellingTapTimer.restart();
                }
            }

            onPointChanged: {
                if (!editPressMonitor.active)
                    return;

                var dx = editPressMonitor.point.position.x - editPressMonitor.pressedAt.x;
                var dy = editPressMonitor.point.position.y - editPressMonitor.pressedAt.y;

                // Moved: that is a drag, a flick or a selection, none of which
                // is a request for the pill.
                if (dx * dx + dy * dy > Units.gu(1.5) * Units.gu(1.5))
                    editPressTimer.stop();
            }
        }

        /*
         * A tap on a selection raises the pill at once, as legacy's did: its
         * mouse-down remembered a press on the selected text and the mouse-up
         * showed the widget with no hold in between.
         *
         * The shell does not know where the selection is, so it asks the other
         * way round: the press found a selection, and a moment after the lift
         * it is still there. A tap anywhere else collapses the selection, so
         * that one does not come back as a selection and gets no pill. The
         * moment is for the input method's report to arrive.
         */
        Timer {
            id: editTapTimer

            interval: 150
            repeat: false

            onTriggered: if (editOverlay.editable && editOverlay.hasSelection && !editOverlay.visible)
                             editOverlay.showAt(editPressMonitor.pressedAt.x,
                                                editPressMonitor.pressedAt.y)
        }

        /*
         * A tap on a misspelled word raises its suggestions, as legacy's
         * spelling widget did on a tap.
         *
         * The shell does not know where the words are, and the keyboard is what
         * says which one is wrong: it reports the misspelled word the caret is in
         * after the tap has put the caret there, so there is a moment to wait for
         * that report, a little longer than the selection tap's. A tap on a word
         * that is fine, or anywhere else, leaves nothing reported and no pill.
         */
        Timer {
            id: spellingTapTimer

            interval: 250
            repeat: false

            onTriggered: {
                var suggestions = editOverlay.keyboardService
                                  ? editOverlay.keyboardService.spellingSuggestions : [];

                if (editOverlay.editable && !editOverlay.visible
                        && !editOverlay.hasSelection && suggestions.length > 0)
                    editOverlay.showSuggestionsAt(editPressMonitor.pressedAt.x,
                                                  editPressMonitor.pressedAt.y)
            }
        }

        Timer {
            id: editPressTimer

            //! Legacy's tap-and-hold time, from startTapAndHoldTimer: 700 ms.
            interval: 700
            repeat: false

            onTriggered: editOverlay.showAt(editPressMonitor.point.position.x,
                                            editPressMonitor.point.position.y)
        }
    }

    StatusBar {
        id: statusBarInstance

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        /*
         * Tall enough for the panel's own hardware to fall inside the bar.
         *
         * Units.gu(3) was the whole story while every panel was a rectangle. On
         * one with a notch it is not: the cutout on radon is 102px deep against a
         * 54px bar, so an app maximized directly below the bar had its top corner
         * cut away by the camera. StatusBar works out how tall it has to be and
         * keeps its contents at gu(3) inside that, so this is the only place the
         * extra height has to be honoured - every other surface here already
         * anchors to statusBarInstance.bottom, and maximizedCardTopMargin above is
         * derived from it, so all of them inset together.
         *
         * Unchanged on every device that declares no cutout: barHeight is then
         * exactly contentHeight, which is Units.gu(3).
         */
        height: statusBarInstance.barHeight

        z: 2 // can only be hidden by a fullscreen window

        windowManagerInstance: windowManager
        gestureHandlerInstance: windowManager.gestureHandlerInstance
        fullLauncherVisible: launcherInstance.fullLauncherVisible
        justTypeLauncherActive: launcherInstance.justTypeLauncherActive
        compositorInstance: compositor

        // Exhibition mode drives the app menu in the status bar: it shows the
        // page on show, and tapping it opens the exhibition page list.
        dockModeAppMenuTitle: dockMode.currentPageTitle
        onDockModeMenuToggled: dockMode.toggleAppMenu();

        onShowPowerMenu: windowManager.showPowerMenu();
    }

    LunaGestureArea {
        id: gestureAreaInstance

        Connections {
            target: AppTweaks
            function onGestureAreaTweakValueChanged () {
                updateShowGestureAreaTweak();
            }

            function updateShowGestureAreaTweak() {
                if (AppTweaks.gestureAreaTweakValue === true){
                    console.log("INFO: Enabling Gesture Area...");
                    gestureAreaInstance.enableGestureArea = true;
                }
                else {
                    console.log("INFO: Disabling Gesture Area...");
                    gestureAreaInstance.enableGestureArea = false;
                }
            }
        }
        anchors.bottom: parent.bottom
        /*
         * Lifted clear of anything against the bottom edge of the panel.
         *
         * Zero on radon held the normal way up - its notch is at the top - and
         * 102px when it is turned over, which is exactly the depth of the notch
         * that is then underneath this strip. Without it the gesture handle and
         * its touch area sit inside the camera hole: the handle is invisible and
         * a swipe from the very bottom lands on glass with no pixels behind it.
         *
         * Everything above anchors to gestureAreaInstance.top (or .bottom when
         * the area is switched off, which is still above the hole), so lifting
         * this lifts the rest with it.
         */
        anchors.bottomMargin: ScreenShape.bottomInset(orientationHelper.orientationAngle)
        anchors.left: parent.left
        anchors.right: parent.right
        height: gestureAreaInstance.enableGestureArea ? Units.gu(4) : Units.gu(0);

        visible: !lockScreen.visible && gestureAreaInstance.enableGestureArea

        z: 3 // the gesture area is in front of everything, like the fullscreen window
    }
}
