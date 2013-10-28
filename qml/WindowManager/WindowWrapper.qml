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
    id: windowWrapper

    // the window app that will be wrapped in this window container
    property alias wrappedWindow: childWrapper.wrappedChild
    // a backlink to the window manager instance
    property variant windowManager

    //   Available window states:
    //    * Carded
    //    * Maximized
    //    * Fullscreen
    property int windowState: WindowState.Carded

    property int windowType: WindowType.Card
    property string appIcon: Qt.resolvedUrl("../images/default-app-icon.png")

    // that part should be moved to a window manager, or maybe to the card view interface
    property variant cardViewParent

    // this is the radius that should be applied to the corners of this window container
    property real cornerRadius: 20

    signal windowVisibilityChanged(bool wrappedChildVisiblity)

    // A simple container, to facilite the wrapping
    Item {
        id: childWrapper
        property Item wrappedChild
        property bool wrappedChildVisiblity

        anchors.fill: parent;

        function setWrappedChild(window) {
            window.parent = childWrapper;
            childWrapper.wrappedChild = window;
            childWrapper.children = [ window ];

            wrappedChildVisiblity = Qt.binding(function() { return wrappedChild.visible })

            // depending on the window type, the height is either forced by the parent or by the child
            if( window.windowType !== WindowType.Overlay && window.windowType !== WindowType.Dashboard )
            {
                /* This resizes only the quick item which contains the child surface but
                 * doesn't really resize the client window */
                window.anchors.fill = childWrapper;

                /* Resize the real client window to have the right size */
                window.changeSize(Qt.size(windowManager.defaultWindowWidth, windowManager.defaultWindowHeight));
            }
            else
            {
                /* change the anchors bindings of the childWrapper and windowWrapper */
                childWrapper.anchors.fill = undefined;
                childWrapper.anchors.top = Qt.binding(function() { return windowWrapper.top })
                childWrapper.anchors.left = Qt.binding(function() { return windowWrapper.left })
                childWrapper.anchors.right = Qt.binding(function() { return windowWrapper.right })
                windowWrapper.height = Qt.binding(function() { return childWrapper.height })

                /* resize the child surface, execpt for height */
                window.anchors.top = Qt.binding(function() { return childWrapper.top })
                window.anchors.left = Qt.binding(function() { return childWrapper.left })
                window.anchors.right = Qt.binding(function() { return childWrapper.right })
                childWrapper.height = Qt.binding(function() { return window.height })

                /* resize the window (keep the height) */
                window.changeSize(Qt.size(windowManager.defaultWindowWidth, window.height));
            }
        }

        function postEvent(event) {
            if( wrappedChild && wrappedChild.postEvent )
                wrappedChild.postEvent(event);
             console.log("Wrapped window: postEvent(" + event + ")");
        }

        onWrappedChildChanged: {
            if( !childWrapper.wrappedChild ) {
                console.log("Wrapped child window has been destroyed!");
                wrappedChildVisiblity = false;

                // ask the window manager to remove this window
                windowManager.removeWindow(windowWrapper);
            }
        }

        onWrappedChildVisiblityChanged: {
            windowWrapper.windowVisibilityChanged(wrappedChildVisiblity);
        }
    }

    // Rounded corners
    RoundedItem {
        id: cornerStaticMask
        anchors.fill: parent
        visible: false
        cornerRadius: windowWrapper.cornerRadius
    }
    CornerShader {
        id: cornerShader
        anchors.fill: parent
        sourceItem: null
        radius: cornerRadius
        visible: false
    }
    state: windowState === WindowState.Fullscreen ? "fullscreen" : windowState === WindowState.Maximized ? "maximized" : "card"

    states: [
        State {
           name: "unintialized"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [] }
        },
        State {
           name: "card"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [] }
        },
        State {
           name: "maximized"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [ wrappedWindow ] }
           StateChangeScript { script: takeFocus() }
        },
        State {
           name: "fullscreen"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [ wrappedWindow ] }
           StateChangeScript { script: takeFocus() }
       }
    ]

    ParallelAnimation {
        id: newParentAnimation
        running: false

        property alias targetNewParent: parentChangeAnimation.newParent
        property alias targetWidth: widthTargetAnimation.to
        property alias targetHeight: heightTargetAnimation.to
        property bool useShaderForNewParent: false

        ParentAnimation {
            id: parentChangeAnimation
            target: windowWrapper
        }
        NumberAnimation {
            id: coordTargetAnimation
            target: windowWrapper
            properties: "x,y"; to: 0; duration: 150
        }
        NumberAnimation {
            id: widthTargetAnimation
            target: windowWrapper
            properties: "width"; duration: 150
        }
        NumberAnimation {
            id: heightTargetAnimation
            target: windowWrapper
            properties: "height"; duration: 150
        }
        NumberAnimation {
            id: scaleTargetAnimation
            target: windowWrapper
            properties: "scale"; to: 1; duration: 100
        }

        onStarted: {
            windowWrapper.anchors.fill = undefined;
            if( useShaderForNewParent )
            {
                cornerShader.sourceItem = childWrapper;
                cornerShader.visible = true;
                cornerStaticMask.visible = false;
            }
        }

        onStopped: {
            windowWrapper.anchors.fill = targetNewParent;
            if( !useShaderForNewParent )
            {
                cornerShader.sourceItem = null;
                cornerShader.visible = false;
                cornerStaticMask.visible = true;
            }
        }
    }

    function setWrappedWindow(window) {
        childWrapper.setWrappedChild(window);

        windowType = window.windowType;

        // fallback to Card if the window type isn't managed yes
        if( windowType === WindowType.BannerAlert ||
            windowType === WindowType.PopupAlert )
            windowType = WindowType.Card
    }

    function setAsCurrentWindow() {
        windowManager.setWindowAsActive(windowWrapper);
    }

    function switchToState(newState)
    {
        windowManager.setWindowAsActive(windowWrapper)

        if( newState === WindowState.Maximized ) {
            windowManager.maximizedMode()
        }
        else if( newState === WindowState.Fullscreen ) {
            windowManager.fullscreenMode()
        }
        else {
            windowManager.cardViewMode()
        }
    }

    function setNewParent(newParent, useShader) {
        newParentAnimation.targetNewParent = newParent;
        newParentAnimation.targetWidth = newParent.width;
        newParentAnimation.targetHeight = newParent.height;
        newParentAnimation.useShaderForNewParent = useShader;
        newParentAnimation.start();

    }

    function startupAnimation() {
        // do the whole startup animation
        // first: show as card in the cardview
        windowManager.setWindowAsActive(windowWrapper);
        windowManager.cardViewMode();
        newParentAnimation.complete(); // force animation to complete now
        windowManager.maximizedMode();
    }

    function postEvent(event) {
        childWrapper.postEvent(event);
    }

    function takeFocus() {
        // Give the focus to this FocusScope
        windowWrapper = true;

        if( wrappedWindow )
            wrappedWindow.takeFocus();
    }
}
