import QtQuick 2.0
import "StatusBarServicesConnector.js" as StatusBarServicesConnector

Item {
    id: compositor
    visible: false

    signal windowAdded(Item window);
    signal windowRemoved(Item window);

    property variant initStatusBar: StatusBarServicesConnector.__init(compositor); // provoke earky init

    QtObject {
        id: localProperties

        property int nextWinId: 0;

        function getNextWinId() {
            nextWinId++;
            return nextWinId;
        }
    }
    ListModel {
        // This model contains the list of the windows that are managed by the compositor.
        id: listWindowsModel

        function getIndexFromProperty(modelProperty, propertyValue) {
            var i=0;
            for(i=0; i<listWindowsModel.count;i++) {
                var item=get(i);
                if(item && item[modelProperty] === propertyValue) {
                    return i;
                }
            }

            console.log("Couldn't find window!");
            return -1;
        }
    }

    Component.onCompleted: {
        createJustTypeLauncherWindow();
    }

    function show() {
        visible = true;
        console.log("Compositor: show()");
    }
    function clearKeyboardFocus() {
        console.log("Compositor: cleared keyboard focus.");
    }

    function createDummyWindow() {
        var windowComponent = Qt.createComponent("../../DummyWindow.qml");
        var window = windowComponent.createObject(compositor);
        window.winId = localProperties.getNextWinId();

        listWindowsModel.append({"window": window, "winId": window.winId});

        compositor.windowAdded(window);
    }

    function createFakeDashboardWindow(options) {
        var windowComponent = Qt.createComponent("../../FakeDashboardWindow.qml");
        var window = windowComponent.createObject(compositor, options);
        window.winId = localProperties.getNextWinId();

        listWindowsModel.append({"window": window, "winId": window.winId});

        compositor.windowAdded(window);
    }

    function createJustTypeLauncherWindow() {
        var windowComponent = Qt.createComponent("../../FakeJustTypeLauncherWindow.qml");
        var window = windowComponent.createObject(compositor);
        window.winId = localProperties.getNextWinId();

        listWindowsModel.append({"window": window, "winId": window.winId});

        compositor.windowAdded(window);
    }

    function closeWindowWithId(winId) {
        console.log("Compositor: closeWindowWithId (winId:" + winId + ")");

        var indexWindow = listWindowsModel.getIndexFromProperty("winId", winId);
        var window = listWindowsModel.get(indexWindow).window;

        if( window )
        {
            console.log("About to destroy window: " + window);
            windowRemoved(window); // I do hope this is synchronous ?

            listWindowsModel.remove(indexWindow);
            window.destroy();
        }
    }
}

