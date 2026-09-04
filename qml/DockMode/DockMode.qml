/*
 * Copyright (C) 2015 Simon Busch <morphis@gravedo.de>
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

Item {
    id: dockMode

    property bool dockModeActive: false
    property Item windowManagerInstance
    property QtObject compositorInstance

    // Drives the exhibition stage's Loader. Kept separate from dockModeActive
    // so that leaving the mode can close the running exhibition applications
    // *before* the stage unloads - binding the Loader straight to
    // dockModeActive would race the handler below and leave those windows
    // behind as ordinary cards.
    property bool __stageLoaded: false

    // The page the device was last left on while docked. Legacy dock mode
    // came back up on whatever you were last looking at rather than always
    // resetting to the clock (DockModeWindowManager's m_defaultIndex, which
    // it also remembered per Touchstone puck). There are no pucks here, so
    // this is the plain last-used index, remembered for as long as the shell
    // is running.
    property int lastUsedIndex: 0

    // What the status bar's app menu reads. The original swapped the title for
    // "Choose an App" while the menu was open and put the current
    // application's name back on close (DockModeMenuManager::activateAppMenu).
    readonly property string currentPageTitle:
        appMenu.isOpen ? "Choose an App"
                       : (carouselLoader.item ? carouselLoader.item.currentPageTitle : "Time")

    // Opened and closed by tapping the app menu in the status bar.
    function toggleAppMenu() {
        appMenu.toggle();
    }

    visible: dockModeActive

    // The applications the user ticked in Settings' Exhibition page, straight
    // from luna-appmanager's dock-mode launch points.
    DockModeLaunchPointsModel {
        id: dockModeLaunchPoints
    }

    onDockModeActiveChanged: {
        console.log("DockMode changed to " + dockModeActive);
        if (dockModeActive) {
            __stageLoaded = true;
            windowManagerInstance.switchToDockMode();
            windowManagerInstance.addTapAction("deactivateDockMode", function() { setDisplayState.call(JSON.stringify({"state":"undock"})); }, null)
        }
        else {
            // Remember where we were, so docking again comes back to the
            // same page instead of resetting to the clock.
            if (carouselLoader.item)
                lastUsedIndex = carouselLoader.item.currentIndex;

            // Take the exhibition applications back down before leaving, the
            // way legacy dock mode did on exit, so they don't linger as cards.
            if (carouselLoader.item)
                carouselLoader.item.closeLaunchedApps();

            __stageLoaded = false;
            appMenu.close();
            windowManagerInstance.switchToCardView();
        }
    }

    LunaService {
        id: setDisplayState
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.display"
        method: "control/setState"
    }

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: {
            service.subscribe("luna://com.palm.display/control/lockStatus", "{\"subscribe\":true}", handleLockStatus, handleError);
        }

        function handleLockStatus(message) {
            console.log("DockMode: Got lock status " + message.payload);
            var response = JSON.parse(message.payload);

            windowManagerInstance.removeTapAction("deactivateDockMode"); // if any was registered, remove it
            dockModeActive = (response.lockState === "dockmode");
        }

        function handleError(message) {
            console.log("Service error: " + message);
        }
    }

    Loader {
        id: carouselLoader

        active: dockMode.__stageLoaded // unload the exhibition stage when not in dockmode

        width: parent.width;
        height: parent.height;
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        sourceComponent: ExhibitionCarousel {
            compositorInstance: dockMode.compositorInstance
            enabledApps: dockModeLaunchPoints.enabledApps
            initialIndex: dockMode.lastUsedIndex

            // Swiping to another page closes the menu, the way picking an
            // entry does.
            onUserInteracted: appMenu.close();
        }
    }

    ExhibitionAppMenu {
        id: appMenu

        // Hangs from the top left, flush against the edge and directly under
        // the status bar, the way the original did.
        anchors.top: parent.top
        anchors.left: parent.left

        enabledApps: dockModeLaunchPoints.enabledApps
        // Guarded on item rather than status: the Loader can still report
        // Ready for an instant after its item has gone, which made this
        // binding read currentIndex off null while leaving exhibition mode.
        currentIndex: carouselLoader.item ? carouselLoader.item.currentIndex : 0

        onPageSelected: (index) => {
            if (carouselLoader.item)
                carouselLoader.item.setCurrentIndex(index);
        }

        // Above the hosted application, not just above the clocks. Legacy
        // kept this menu in its own layer over the dock windows
        // (DockModeMenuManager, sitting on top of DockModeWindowManager), and
        // an exhibition application fills the whole stage, so anything less
        // would open the menu behind it.
        z: 1000
    }
}
