import QtQuick 2.0
import LunaNext 0.1

Item {
    id: cardWindow

    property Item windowWrapper
    property Item cardView

    visible: false

    onVisibleChanged: if( windowWrapper && visible ) windowWrapper.firstCardDisplayDone = true;

    Component.onCompleted: {
        windowWrapper.cardViewParent = cardWindow;
    }

    function isWindowCarded() {
        return (windowWrapper && windowWrapper.windowState === WindowState.Carded);
    }
}
