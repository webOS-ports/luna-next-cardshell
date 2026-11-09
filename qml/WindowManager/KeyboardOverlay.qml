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
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

Item {
    id: keyboardOverlayItem
    property var compositorInstance

    //! The keyboard's own window, the screen-sized one its keys are drawn into.
    //! Null until the input method has put one up; cleared again if it goes.
    property Item panelWindow: null

    /*!
     * \brief Where the keyboard is on screen, in this item's coordinates.
     *
     * An empty rectangle while no keyboard is showing. For anything the shell
     * draws above the keyboard - the edit overlay is one - to stay off it.
     *
     * The panel window is the whole of this item and mostly transparent: what is
     * keyboard is the strip its window mask leaves, which the compositor takes
     * as the input panel's rectangle. That rectangle outlives the keyboard,
     * though - hiding unmaps the window and leaves the last rectangle behind -
     * so it only counts while the window has something on screen. The keyboard
     * with nothing to show (keys hidden behind a physical keyboard, no candidate
     * bar) masks itself down to a single pixel, which is not a keyboard either.
     *
     * While one of the keyboard's popups is up the whole area is the keyboard's:
     * it is dimmed, and a press anywhere in it is a press that closes the popup.
     */
    readonly property rect keyboardRect: {
        var none = Qt.rect(0, 0, 0, 0);

        if (!keyboardOverlayItem.visible)
            return none;

        if (surfaceShowing(overlayBackgroundArea.associatedPopupWindow))
            return Qt.rect(0, 0, keyboardOverlayItem.width, keyboardOverlayItem.height);

        var window = keyboardOverlayItem.panelWindow;
        var inputMethod = compositorInstance ? compositorInstance.inputMethod : null;
        if (!window || !window.visible || !surfaceShowing(window) || !inputMethod)
            return none;

        var panel = inputMethod.panelRect;
        if (panel.width <= 1 || panel.height <= 1)
            return none;

        return Qt.rect(window.x + panel.x, window.y + panel.y, panel.width, panel.height);
    }

    //! Whether a keyboard window has anything on screen: a WebOSSurfaceItem whose
    //! surface is mapped. Hiding the window unmaps it.
    function surfaceShowing(window) {
        return !!window && !!window.surface && window.surface.hasContent;
    }

    WindowModel {
        id: listKeyboardsModel
        surfaceSource: compositorInstance.surfaceModel
        windowType: "_WEBOS_WINDOW_TYPE_KEYBOARD"

        onRowsInserted: (index, first, last) => {
            appendKeyboardWindow(listKeyboardsModel.get(last));
        }
    }

    Rectangle {
        id: overlayBackgroundArea
        anchors.fill: parent
        color: "grey"
        opacity: 0.2
        visible: associatedPopupWindow !== null
        property Item associatedPopupWindow
        MouseArea {
            anchors.fill: overlayBackgroundArea
            onClicked: {
                compositorInstance.closeWindow(overlayBackgroundArea.associatedPopupWindow);
                overlayBackgroundArea.associatedPopupWindow = null;
            }
        }
    }

    onWidthChanged:  updateOverlaySizes();
    onHeightChanged: updateOverlaySizes();

    function updateOverlaySizes() {
        console.log("new keyboard overlay window size = " + keyboardOverlayItem.width +"x"+ keyboardOverlayItem.height);
        for( var i = 0; i < listKeyboardsModel.count; ++i ) {
            var window = listKeyboardsModel.get(i);
            if(!window.isPopup) {
                window.changeSize(Qt.size(keyboardOverlayItem.width, keyboardOverlayItem.height));
            }
        }
    }

    function appendKeyboardWindow(window) {
        console.log("KeyboardOverlay: adding " + window);

        window.parent = keyboardOverlayItem;
        if(!window.isPopup) {
            window.anchors.fill = keyboardOverlayItem;
            window.changeSize(Qt.size(keyboardOverlayItem.width, keyboardOverlayItem.height));
            keyboardOverlayItem.panelWindow = window;
        }
        else {
            window.anchors.centerIn = keyboardOverlayItem;
            overlayBackgroundArea.associatedPopupWindow = window;
        }
    }
}
