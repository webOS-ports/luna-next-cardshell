import QtQuick 2.0
import QtQml 2.15

Item {
    id: flickableHandleArea

    property Flickable flickable
    property real contentOffset

    property alias handleHeight: handleItem.height;
    property alias handleWidth: handleItem.width;
    property alias handleItemOffset: handleItem.y;

    signal handleReleased()

    Binding {
        target: flickable
        property: "contentY"
        value: contentOffset - handleItem.y
        when: !!contentOffset
        restoreMode: Binding.RestoreBinding
    }

    Item {
        id: handleItem
        y: 0; x: 0

        Behavior on y {
            SmoothedAnimation { duration: 300; velocity: 200; easing.type: Easing.OutQuad }
        }
    }

    MouseArea {
        id: clicker;
        drag {
            target: handleItem;
            axis: Drag.YAxis;
        }
        anchors { fill: handleItem; }

        onPressed: {
            contentOffset = flickable.contentY + handleItem.y; // disable the binding
        }
        onReleased: {
            handleReleased();
        }
    }
}
