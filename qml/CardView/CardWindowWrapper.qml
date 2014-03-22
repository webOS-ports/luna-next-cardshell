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
import QtGraphicalEffects 1.0
import LunaNext 0.1

import "../Utils"

FocusScope {
    id: cardWrapperItem

    // the window app that will be wrapped in this window container
    property alias wrappedWindow: childWrapper.wrappedChild

    // a backlink to the cardView instance
    property variant cardView

    //   Available window states:
    //    * Carded
    //    * Maximized
    //    * Fullscreen
    property int windowState: WindowState.Carded
    onWindowStateChanged: console.log("windowState is now: " + windowState);

    property int windowType: WindowType.Card
    property string appIcon: Qt.resolvedUrl("../images/default-app-icon.png")

    // that part should be moved to a window manager, or maybe to the card view interface
    property variant cardViewParent

    // this is the radius that should be applied to the corners of this window container
    property real cornerRadius: 20

    property bool aboutToBeDestroyed: false;

    // A simple container, to facilite the wrapping
    Item {
        id: childWrapper
        property Item wrappedChild

        anchors.fill: parent;

        function setWrappedChild(window) {
            childWrapper.wrappedChild = window;
            childWrapper.children = [ window ];

            if( window ) {
                window.parent = childWrapper;

                /* This resizes only the quick item which contains the child surface but
                 * doesn't really resize the client window */
                window.anchors.fill = childWrapper;

                /* Resize the real client window to have the right size */
                window.changeSize(Qt.size(cardView.defaultWindowWidth, cardView.defaultWindowHeight));
            }
        }
    }

    state: windowState === WindowState.Fullscreen ? "fullscreen" : windowState === WindowState.Maximized ? "maximized" : "card"
    states: [
        State {
           name: "unintialized"
           PropertyChanges { target: cardWrapperItem; Keys.forwardTo: [] }
           StateChangeScript { script: loseFocus() }
        },
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

    function setWrappedWindow(window) {
        childWrapper.setWrappedChild(window);

        if( window )
        {
            windowType = window.windowType;
            window.userData = this

            // fallback to Card if the window type isn't managed yes
            if( windowType === WindowType.BannerAlert ||
                windowType === WindowType.PopupAlert )
                windowType = WindowType.Card
        }
    }

    function setAsCurrentWindow() {
        cardView.setCurrentCard(wrappedWindow);
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

    function requestDestruction() {
        if( !aboutToBeDestroyed ) {
            aboutToBeDestroyed = true;
            cardView.removeCard(wrappedWindow)
        }
    }
}
