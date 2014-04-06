import QtQuick 2.0

import LunaNext.Compositor 0.1

/*
 * The CardGroupModel describes how the cards are organized into groups.
 * Each group corresponds to a ListElement of the ListModel, and contains
 * the list of the windows it aggregates.
 * A group is visualized with the CardGroupDelegate delegate.
 */

ListModel {
    id: listCardGroupsModel

    property WindowModel listCardsModel: WindowModel {
        windowTypeFilter: WindowType.Card
/*
        onRowsAboutToBeInserted: listCardsView.newCardInserted = true;
*/
        onRowsAboutToBeRemoved: removeWindow(listCardsModel.getByIndex(last));
        onRowsInserted: {
            var newWindow = listCardsModel.getByIndex(listCardsModel.count-1);

            createNewGroup(newWindow);
            // DEBUG: move the new window in the previous group, and build groups of 4 windows
            if( count>1 && count%4 !== 0 )
                moveWindowGroup(newWindow, listCardGroupsModel.count-1, listCardGroupsModel.count-2);
        }
    }

    function createNewGroup(window) {
        // create a new group with only one window
        listCardGroupsModel.append({"windowList": [ { "window":window } ]});
    }

    function removeWindow(window) {
        // remove the window from the group it belongs to
        var windowRemoved = false;

        var groupIndex = 0;
        for( groupIndex=0; !windowRemoved && groupIndex<listCardGroupsModel.count; ++groupIndex ) {
            var windowList = listCardGroupsModel.get(groupIndex).windowList;
            var windowIndex=0;
            for( windowIndex=0; !windowRemoved && windowIndex<windowList.count; ++windowIndex ) {
                if( windowList.get(windowIndex).window === window ) {
                    windowList.remove(windowIndex);

                    // If the group is now empty, remove it
                    if( windowList.count === 0 )
                        listCardGroupsModel.remove(groupIndex);

                    windowRemoved = true;
                }
            }
        }
    }

    function moveWindowGroup(window, groupFrom, groupTo) {
        if( groupFrom === groupTo ) return;

        // first, remove the window from the origin group
        var windowListFrom = listCardGroupsModel.get(groupFrom).windowList;
        var i=0;
        for( i=0; i<windowListFrom.count; ++i ) {
            if( windowListFrom.get(i).window === window ) {
                windowListFrom.remove(i);
                break;
            }
        }

        // then add it to the dest group
        if( groupTo === -1 || groupTo === listCardGroupsModel.count ) {
            createNewGroup(window);
        }
        else {
            var windowListTo = listCardGroupsModel.get(groupTo).windowList;
            windowListTo.append({"window": window});
        }

        // Clean up the origin group if it is empty
        if( windowListFrom.count === 0 )
            listCardGroupsModel.remove(groupFrom);
    }
}

