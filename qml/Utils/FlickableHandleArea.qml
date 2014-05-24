import QtQuick 2.0;

Item {
    property Flickable flickable
    property real contentOffset
    property bool flicking: false;

    signal handleReleased(real dy)

    Binding {
        target: flickable
        property: "contentY"
        value: contentOffset - handleItem.y
        when: flicking
    }

    Connections {
        target: flickable
        onContentYChanged: console.log("contentY = " + flickable.contentY);
    }

    Item {
        id: handleItem
        y: 0; x: 0
        width: parent.width; height: parent.height
    }

    MouseArea {
        id: clicker;
        drag {
            target: handleItem;
            axis: Drag.YAxis;
        }
        anchors { fill: parent; }
        onPressed: {
            contentOffset = flickable.contentY;
            flicking = true;
        }
        onReleased: {
            //flickable.flick(0,0);
            flicking = false;
            handleReleased(handleItem.y);
        }

        drag.onActiveChanged: {
            if( !drag.active ) handleItem.y = 0;
            var tmp = flickable.currentIndex;
            flickable.currentIndex = -1;
            flickable.currentIndex = tmp; // trigger the event
        }
    }
}
