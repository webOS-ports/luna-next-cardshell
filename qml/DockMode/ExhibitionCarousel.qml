/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
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
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import WebOSCoreCompositor 1.0

/*
 * The exhibition mode stage: the clocks, plus one full-screen page per
 * exhibition-enabled application, swipeable left/right.
 *
 * This is the piece legacy webOS had in DockModeWindowManager - the clock is
 * always the first (and fallback) page, exactly as it was there, and every
 * application the user ticked in Settings' Exhibition page follows it.
 *
 * Applications are launched lazily: an application is only started once its
 * page becomes the current one, and it is launched with the very launch
 * parameters the legacy dock mode used - { windowType: "dockModeWindow",
 * dockMode: true } - which is what the ported core applications still look
 * for (see com.palm.app.photos' PhotoAppLauncher.appSelect, which switches to
 * its slideshow face on exactly that, and com.palm.app.clock likewise).
 */
Item {
    id: carousel

    property QtObject compositorInstance
    property var enabledApps: []

    // Index 0 is the clocks; app pages follow in enabledApps order.
    readonly property int currentIndex: pagesListView.currentIndex
    readonly property bool onClockPage: pagesListView.currentIndex === 0

    // Page to open on. Legacy dock mode came back up on whatever you were
    // last looking at (DockModeWindowManager's m_defaultIndex) rather than
    // always resetting to the clock, so the shell hands that back in here.
    property int initialIndex: 0

    readonly property string currentPageTitle:
        pagesListView.currentIndex > 0 &&
        pagesListView.currentIndex <= carousel.enabledApps.length
            ? carousel.enabledApps[pagesListView.currentIndex - 1].title
            : "Time"

    // Raised whenever the user moved between pages, so the switcher can show
    // itself briefly. Deliberately not a tap handler: the clocks have their
    // own horizontal list to swipe through the three faces, and an overlaid
    // MouseArea would swallow those drags.
    signal userInteracted()

    function setCurrentIndex(index) {
        // A deliberate move counts as the restore having happened, so a
        // late-arriving application list can't yank the page away afterwards.
        carousel.__initialIndexRestored = true;
        pagesListView.currentIndex = index;
    }

    property bool __initialIndexRestored: false

    function restoreInitialIndex() {
        if (carousel.__initialIndexRestored)
            return;

        if (carousel.initialIndex <= 0) {
            carousel.__initialIndexRestored = true;
            return;
        }

        // Guarded against a shrunken list - an application may have been
        // switched off in Settings since the last time we were docked.
        if (carousel.initialIndex < pagesListView.count) {
            pagesListView.currentIndex = carousel.initialIndex;
            carousel.__initialIndexRestored = true;
        }
    }

    // Application windows we launched, so exhibition mode can take them back
    // down when it exits.
    property var launchedAppIds: []

    property LunaService launchService: LunaService {
        id: launchService
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            carousel.__serviceReady = true;
            carousel.__flushPendingLaunches();
        }
    }

    // Resuming onto an application page can come round within a second of the
    // shell starting - before the service handle is registered, which fails
    // the launch outright ("Failed to call remote service"). Anything asked
    // for before then waits here.
    property bool __serviceReady: false
    property var __pendingLaunches: []

    function __flushPendingLaunches() {
        var pending = carousel.__pendingLaunches;
        carousel.__pendingLaunches = [];
        pending.forEach(function (appId) { carousel.launchExhibitionApp(appId); });
    }

    // The windows an exhibition application may appear as. A runtime that
    // knows about dock mode gives it ExhibitionState.dockWindowType; one that
    // doesn't still produces an ordinary card, so both are accepted here and
    // the application is picked out by id.
    property WindowModel cardWindows: WindowModel {
        id: cardWindows
        surfaceSource: carousel.compositorInstance ? carousel.compositorInstance.surfaceModel : null
        acceptFunction: "acceptExhibitionCandidate"

        function acceptExhibitionCandidate(surfaceItem) {
            return surfaceItem.type === "_WEBOS_WINDOW_TYPE_CARD" ||
                   surfaceItem.type === ExhibitionState.dockWindowType;
        }

        onRowsInserted: carousel.windowsUpdated()
        onRowsRemoved: carousel.windowsUpdated()
    }

    // Emitted whenever the set of card windows changed, so each application
    // page can re-check whether its own window has shown up (or gone away).
    signal windowsUpdated()

    // Used for the splash shown while an application is still starting up.
    property ExhibitionAppInfo appInfo: ExhibitionAppInfo {}

    function findWindowForAppId(appId) {
        for (let i = 0; i < cardWindows.count; i++) {
            let window = cardWindows.get(i);
            if (window && window.appId === appId)
                return window;
        }
        return null;
    }

    function launchExhibitionApp(appId) {
        if (carousel.launchedAppIds.indexOf(appId) < 0)
            carousel.launchedAppIds.push(appId);

        // Claim it before the window turns up, so the card views filter it
        // out the moment it is created rather than after the fact.
        ExhibitionState.own(appId);

        if (!carousel.__serviceReady) {
            console.log("ExhibitionCarousel: deferring launch of " + appId + " until the service is up");
            if (carousel.__pendingLaunches.indexOf(appId) < 0)
                carousel.__pendingLaunches.push(appId);
            return;
        }

        console.log("ExhibitionCarousel: launching exhibition app " + appId);

        launchService.call("luna://com.webos.service.applicationManager/launch",
            JSON.stringify({"id": appId,
                            "params": {"windowType": "dockModeWindow", "dockMode": true}}),
            function (message) {},
            function (message) {
                console.log("ExhibitionCarousel: could not launch " + appId + ": " + message);
            });
    }

    // Legacy closed every dock mode application but the default one when
    // leaving the mode (DockModeWindowManager::setDockModeState, with
    // dockModeCloseOnExit defaulting to true). Do the same, so exhibition
    // applications don't linger as cards after undocking.
    function closeLaunchedApps() {
        if (!carousel.compositorInstance)
            return;

        carousel.launchedAppIds.forEach(function (appId) {
            let window = carousel.findWindowForAppId(appId);
            if (window) {
                console.log("ExhibitionCarousel: closing exhibition app " + appId);
                carousel.compositorInstance.closeWindow(window);
            }
        });
        carousel.launchedAppIds = [];
        ExhibitionState.releaseAll();
    }

    ListView {
        id: pagesListView

        anchors.fill: parent
        // Without clipping the neighbouring pages paint outside the view and
        // bleed onto the current one - same reason Clocks.qml clips its own
        // horizontal list.
        clip: true
        focus: true
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        boundsBehavior: Flickable.DragOverBounds
        highlightMoveDuration: 250

        model: [{"isClock": true, "appId": "", "title": "Time"}].concat(carousel.enabledApps)

        onCurrentIndexChanged: carousel.userInteracted()

        // Restore the page the shell remembered from the last time the device
        // was docked. The enabled applications arrive over LS2, so at
        // completion this list usually holds nothing but the clock - hence
        // waiting for the count to grow rather than restoring once and
        // missing. Applied at most once, so a swipe afterwards stands.
        Component.onCompleted: carousel.restoreInitialIndex()
        onCountChanged: carousel.restoreInitialIndex()

        delegate: Item {
            id: pageItem

            width: pagesListView.width
            height: pagesListView.height

            readonly property bool isCurrentPage: ListView.isCurrentItem
            readonly property var pageData: modelData

            Loader {
                anchors.fill: parent
                // The components below are declared inside this delegate on
                // purpose: a Component picks up the scope it is declared in,
                // so one declared at carousel level could not see pageItem.
                sourceComponent: pageItem.pageData.isClock ? clockPageComponent
                                                           : appPageComponent
            }

            Component {
                id: clockPageComponent

                // Left untouched: the clocks bring their own horizontal list
                // to swipe between the analog/digital faces.
                Clocks {}
            }

            Component {
                id: appPageComponent

                ExhibitionWindowWrapper {
                    id: appPage

                    readonly property string appId: pageItem.pageData.appId

                    active: pageItem.isCurrentPage
                    appTitle: pageItem.pageData.title

                    property bool launchRequested: false

                    function refreshWindow() {
                        appPage.wrappedWindow = carousel.findWindowForAppId(appPage.appId);

                        // The application is only started once its page is
                        // actually shown, and only once - relaunching would
                        // pull it back out of the dock-mode face it is in.
                        if (!appPage.wrappedWindow && pageItem.isCurrentPage && !appPage.launchRequested) {
                            appPage.launchRequested = true;
                            carousel.launchExhibitionApp(appPage.appId);
                        }

                        // If the window went away (the application crashed,
                        // or its card was closed), allow a fresh launch the
                        // next time this page comes round.
                        if (!appPage.wrappedWindow && appPage.launchRequested && !pageItem.isCurrentPage)
                            appPage.launchRequested = false;
                    }

                    // The launch point normally carries an absolute icon path
                    // already; only fall back to a getAppInfo lookup if it
                    // didn't.
                    appIcon: pageItem.pageData.icon || ""

                    Component.onCompleted: {
                        refreshWindow();
                        if (appPage.appIcon.length === 0)
                            carousel.appInfo.resolveIcon(appPage.appId, function (path) {
                                appPage.appIcon = path;
                            });
                    }

                    onActiveChanged: refreshWindow();

                    Connections {
                        target: carousel
                        function onWindowsUpdated() { appPage.refreshWindow(); }
                    }
                }
            }
        }
    }
}
