import QtQuick 2.0

Item {
    id: compositor
    visible: false

    signal windowAdded(Item window);
    signal windowRemoved(Item window);

    function show() {
        visible = true;
        console.log("Compositor: show()");
    }
    function clearKeyboardFocus() {
        console.log("Compositor: cleared keyboard focus.");
    }

    function closeWindowWithId(appId) {
        console.log("Compositor: closeWindowWithId (appId:" + appId + ")");
    }
}

