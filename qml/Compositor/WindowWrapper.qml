import QtQuick 2.0
import QtGraphicalEffects 1.0
import LunaNext 0.1

Item {
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
    property bool firstCardDisplayDone: false

    // that part should be moved to a window manager, or maybe to the card view interface
    property variant cardViewParent

    // this is the radius that should be applied to the corners of this window container
    property real cornerRadius: 20

    // A simple container, to facilite the wrapping
    Item {
        id: childWrapper
        property variant wrappedChild

        anchors.fill: parent;

        function setWrappedChild(window) {
            window.parent = childWrapper;
            childWrapper.wrappedChild = window;
            childWrapper.children = [ window ];
            window.anchors.fill = childWrapper;
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
    onFirstCardDisplayDoneChanged: if( firstCardDisplayDone === true ) {
                                       startupAnimation();
                                   }

    states: [
        State {
           name: "unintialized"
        },
        State {
           name: "card"
        },
        State {
           name: "maximized"
        },
        State {
           name: "fullscreen"
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
        windowManager.setToCard(windowWrapper);
        newParentAnimation.complete(); // force animation to complete now
        windowManager.setToMaximized(windowWrapper);
    }
}
