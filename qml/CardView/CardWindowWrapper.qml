/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import Qt5Compat.GraphicalEffects

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0

import "../Utils"
import "../WindowStateStub.js" as WindowState

FocusScope {
    id: cardWrapperItem

    // the window app that will be wrapped in this window container
    property alias wrappedWindow: childWrapper.wrappedChild

    // a backlink to the cardView instance
    property Item cardView

    //   Available window states:
    //    * Carded
    //    * Maximized
    //    * Fullscreen
    property int windowState: WindowState.Carded

    property bool isFullScreenMode: false

    // this is the radius that should be applied to the corners of this window container
    property real cornerRadius: 20
    property bool useShaderCorner: true

    signal clicked();
    signal startDrag();
    signal stopDrag();

    // Drag management
    Drag.active: false
    Drag.source: cardWrapperItem
/*
    CardWindowSplash {
        id: splash
        appIcon: wrappedWindow !== null ? wrappedWindow.customImageFilePath : ""
        anchors.fill: parent;
        state: "hidden"
        z: 10
    }
*/
    function windowVisibleChanged() {
        if(wrappedWindow.exposed) {
            splash.state = "hidden";
            wrappedWindow.mappedChanged.disconnect(windowVisibleChanged);
        }
    }

    // A simple container, to facilite the wrapping
    Item {
        id: childWrapper
        property Item wrappedChild

        anchors.fill: parent;
        visible: !cardWrapperItem.useShaderCorner

        function setWrappedChild(window) {
            childWrapper.wrappedChild = window;
            childWrapper.children = [ window ];

            if( window ) {
                if (window.mapped)
                    splash.state = "hidden";

                window.parent = childWrapper;

                /* This resizes only the quick item which contains the child surface but
                 * doesn't really resize the client window */
                window.anchors.fill = childWrapper;

                /* Resize the real client window to have the right size */
                window.changeSize(Qt.size(cardView.defaultWindowWidth, cardView.defaultWindowHeight));

                window.exposedChanged.connect(windowVisibleChanged);
            }
        }
    }
    // Rounded corners (static version)
    RoundedItem {
        id: cornerStaticMask
        anchors.fill: cardWrapperItem
        visible: !useShaderCorner && windowState !== WindowState.Fullscreen
        cornerRadius: cardWrapperItem.cornerRadius
    }
    // Rounded corners (shader version)
    OpacityMask {
        anchors.fill: cardWrapperItem
        source: childWrapper
        invert: true
        maskSource: cornerStaticMask
        visible: useShaderCorner
    }

    MouseArea {
        id: dragMouseArea
        anchors.fill: cardWrapperItem

        enabled: windowState === WindowState.Carded
        /*
        enabled: slidingCardDelegate.isCurrentItem &&
                 slidingCardDelegate.windowUserData && slidingCardDelegate.windowUserData.windowState === WindowState.Carded
        */
        property bool held: false;

        drag.target: held ? cardWrapperItem : undefined
        drag.axis: Drag.XAndYAxis
        drag.filterChildren: true

        onClicked: {
            cardWrapperItem.clicked();
        }

        onPressAndHold: {
            // switch to drag'n'drop state
            console.log("Card wrapper: press and hold");

            mouse.accepted = true;
            cardWrapperItem.Drag.hotSpot.x = mouse.x
            cardWrapperItem.Drag.hotSpot.y = mouse.y
            held = true;
            cardWrapperItem.startDrag();
            cardWrapperItem.Drag.active = true;
        }
        onReleased: {
            // stop the drag'n'drop
            if( held ) {
                console.log("Card wrapper: released drag");
                cardWrapperItem.Drag.drop();
                cardWrapperItem.Drag.active = false;
                held = false;
                cardWrapperItem.stopDrag();
            }
        }
    }

    state: windowState === WindowState.Fullscreen ? "fullscreen" : windowState === WindowState.Maximized ? "maximized" : "card"
    states: [
        State {
           name: "card"
           PropertyChanges { target: cardWrapperItem; Keys.forwardTo: [] }
           StateChangeScript { script: loseFocus() }
        },
        State {
           name: "maximized"
           PropertyChanges { target: cardWrapperItem; Keys.forwardTo: [ wrappedWindow ] }
           StateChangeScript { script: takeFocus() }
        },
        State {
           name: "fullscreen"
           PropertyChanges { target: cardWrapperItem; Keys.forwardTo: [ wrappedWindow ] }
           StateChangeScript { script: takeFocus() }
       }
    ]

    Connections {
        target: cardView
        function onDefaultWindowWidthChanged() {
            syncClientWindowSize();
        }
        function onDefaultWindowHeightChanged() {
            syncClientWindowSize();
        }
    }

    function setWrappedWindow(window) {
        childWrapper.setWrappedChild(window);
        if( window ) {
            window.userData = this
        }
    }

    function setAsCurrentWindow() {
        cardView.setCurrentCard(wrappedWindow);
    }
    
    function syncClientWindowSize() {
        if( cardWrapperItem.windowState !== WindowState.Carded && wrappedWindow ) {
            /* Resize the real client window to have the right size */
            wrappedWindow.changeSize(Qt.size(cardWrapperItem.width, cardWrapperItem.height));
        }
        else if(wrappedWindow) {
            wrappedWindow.changeSize(Qt.size(cardView.defaultWindowWidth, cardView.defaultWindowHeight));
        }
    }    

    function loseFocus() {
        cardWrapperItem.focus = false;
    }

    function takeFocus() {
        // Give the focus to this FocusScope
        cardWrapperItem.focus = true;

        if( wrappedWindow )
            wrappedWindow.takeFocus();
    }

    function destroyIfNeeded() {
        if( !cardWrapperItem.parent && !cardWrapperItem.wrappedWindow ) {
             // we are all alone, commit suicide
             cardWrapperItem.destroy();
        }
    }

    onParentChanged: destroyIfNeeded();
    onWrappedWindowChanged: destroyIfNeeded();
}
