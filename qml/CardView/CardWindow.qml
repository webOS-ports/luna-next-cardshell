import QtQuick 2.0
import LunaNext 0.1

Item {
    id: cardWindow

    property Item windowWrapper
    property Item cardView

    property bool isCurrentCard: false
    property bool firstCardDisplayDone: false

    visible: false

    Component.onCompleted: {
        windowWrapper.cardViewParent = cardWindow;
    }

    function isWindowCarded() {
        return (windowWrapper && windowWrapper.windowState === WindowState.Carded);
    }
    function setCurrentCardState(isCurrent)
    {
        isCurrentCard = isCurrent;
        if( isCurrentCard && !firstCardDisplayDone )
        {
            firstCardDisplayDone = true;
            windowWrapper.startupAnimation();
        }
    }
}
