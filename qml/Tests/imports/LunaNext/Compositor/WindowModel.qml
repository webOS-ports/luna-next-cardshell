import QtQuick 2.0

import "WindowTypeStub.js" as WindowType
import "Singletons"

ListModel {
    id: windowModel

    property int windowTypeFilter: 0;
    property ListModel _referenceModel

    signal rowsAboutToBeInserted(variant index, int first, int last)
    signal rowsAboutToBeRemoved(variant index, int first, int last)
    signal rowsInserted(variant index, int first, int last)
    signal rowsRemoved(variant index, int first, int last)
    signal dataChanged(variant topLeft, variant bottomRight, variant roles)

    function get(index) {
        return _referenceModel.get(index);
    }

    function getByIndex(i) {
        if( i<0 || i>=_referenceModel.count ) {
            console.log("index "+ i +" out of range !");
        }

        return get(i).window;
    }

    onRowsInserted: {
        windowModel.append( _referenceModel.get(last) );
    }
    onRowsRemoved: {
        windowModel.remove( last );
    }

    Component.onCompleted: {
        if( windowTypeFilter === WindowType.Card )
            _referenceModel = WindowModelSingleton.cardListModel;
        else if( windowTypeFilter === WindowType.Launcher )
            _referenceModel = WindowModelSingleton.launcherListModel;
        else if( windowTypeFilter === WindowType.Dashboard )
            _referenceModel = WindowModelSingleton.dashboardListModel;
        else if( windowTypeFilter === WindowType.PopupAlert )
            _referenceModel = WindowModelSingleton.popupAlertListModel;
        else if( windowTypeFilter === WindowType.BannerAlert )
            _referenceModel = WindowModelSingleton.bannerAlertListModel;
        else if( windowTypeFilter === WindowType.Overlay )
            _referenceModel = WindowModelSingleton.overlayListModel;
        else if( windowTypeFilter === WindowType.Pin )
            _referenceModel = WindowModelSingleton.pinListModel;

        // windowModel.count = Qt.binding(function() { return _referenceModel.count });
        _referenceModel.rowsAboutToBeInserted.connect(rowsAboutToBeInserted);
        _referenceModel.actualRowsAboutToBeRemoved.connect(rowsAboutToBeRemoved);
        _referenceModel.actualRowsInserted.connect(rowsInserted);
        _referenceModel.rowsRemoved.connect(rowsRemoved);
        _referenceModel.dataChanged.connect(dataChanged);
        // _referenceModel.countChanged.connect(updateCount);
    }
}
