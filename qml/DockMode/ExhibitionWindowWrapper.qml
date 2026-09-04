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
import LunaNext.Common 0.1

import "../CardView"

// A minimal full-screen embedder for one exhibition app's window - the
// dock-mode counterpart of CardView/CardWindowWrapper.qml, without the
// drag/reorder/rounded-corner machinery that file needs for the card stack
// (exhibition mode only ever shows one window at a time, edge to edge).
FocusScope {
    id: windowWrapper

    // The compositor window to display, or null while it hasn't launched/
    // mapped yet (the splash is shown in that case).
    property Item wrappedWindow

    // True while this is the carousel's current entry - only then does it
    // take keyboard/input focus.
    property bool active: false

    property string appTitle: ""
    property string appIcon: ""

    // Set once an application has been given long enough to put a window up
    // and hasn't. Some applications never do - com.achunt.jukie opens none
    // even on an ordinary launch - and a splash that pulses for ever reads as
    // the shell having hung rather than the application having nothing to
    // show.
    property bool loadTimedOut: false

    function windowVisibleChanged() {
        // WebOSSurfaceItem has no "mapped" property, only "exposed" - the
        // mapped check in CardWindowWrapper is dead code, so don't copy it.
        if (wrappedWindow && wrappedWindow.exposed)
            splash.state = "hidden";
    }

    Timer {
        id: loadTimeoutTimer
        interval: 20000
        running: windowWrapper.active && !windowWrapper.wrappedWindow
        onTriggered: windowWrapper.loadTimedOut = true
    }

    function syncWindowGeometry() {
        if (!wrappedWindow)
            return;
        wrappedWindow.anchors.fill = contentArea;
        wrappedWindow.changeSize(Qt.size(windowWrapper.width, windowWrapper.height));
    }

    onWrappedWindowChanged: {
        if (wrappedWindow) {
            loadTimedOut = false;
            wrappedWindow.parent = contentArea;
            syncWindowGeometry();
            wrappedWindow.exposedChanged.connect(windowVisibleChanged);
            if (wrappedWindow.mappedChanged)
                wrappedWindow.mappedChanged.connect(windowVisibleChanged);
            windowVisibleChanged();
            updateExposed();
            if (active)
                takeFocus();
        } else {
            splash.state = "visible";
        }
    }

    onActiveChanged: {
        updateExposed();
        if (active)
            takeFocus();
    }

    onWidthChanged: syncWindowGeometry();
    onHeightChanged: syncWindowGeometry();

    function takeFocus() {
        windowWrapper.focus = true;
        if (wrappedWindow)
            wrappedWindow.takeFocus();
    }

    // Tell the client whether it is on screen. This is not a passive flag:
    // WebOSSurfaceItem::setExposed sends shellSurface->exposed() to the
    // application, which is how it learns it is visible and should render.
    // The card views get this through the compositor's fullscreen path;
    // exhibition mode hosts its window itself, so it has to say so here -
    // without it the application stays blank behind the splash.
    function updateExposed() {
        if (!wrappedWindow)
            return;

        wrappedWindow.exposed = windowWrapper.active;
    }

    Item {
        id: contentArea
        anchors.fill: parent
    }

    CardWindowSplash {
        id: splash
        appIcon: windowWrapper.appIcon
        anchors.fill: parent
        visible: !windowWrapper.loadTimedOut
        z: 10
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - Units.gu(4)
        visible: windowWrapper.loadTimedOut
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: (windowWrapper.appTitle.length > 0 ? windowWrapper.appTitle : "This application")
              + " has nothing to show here."
        color: "#9a9a9a"
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        z: 11
    }

    Text {
        anchors.top: parent.verticalCenter
        anchors.topMargin: Units.gu(6)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: splash.state === "visible" && windowWrapper.appTitle.length > 0
        text: windowWrapper.appTitle
        color: "#e1e1e1"
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("large")
        z: 10
    }
}
