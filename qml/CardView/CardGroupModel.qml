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

    signal newCardInserted(int group, int index, Item newWindow)
    signal cardRemoved()

    property WindowModel listCardsModel: WindowModel {
        windowTypeFilter: WindowType.Card

        onRowsAboutToBeRemoved: removeWindow(listCardsModel.getByIndex(last));
        onRowsInserted: {
            var newWindow = listCardsModel.getByIndex(last);
            var groupIndexForInsertion = listCardGroupsModel.count;
            if( newWindow.parentWinId ) {
                var windowFound = false;
                // First, we have to find which group contains this parent window
                for( var groupIndex=0; !windowFound && groupIndex<listCardGroupsModel.count; ++groupIndex ) {
                    var windowList = listCardGroupsModel.get(groupIndex).windowList;
                    var windowIndex=0;
                    for( windowIndex=0; !windowFound && windowIndex<windowList.count; ++windowIndex ) {
                        if( windowList.get(windowIndex).window.winId === newWindow.parentWinId ) {
                            groupIndexForInsertion = groupIndex;
                            windowFound = true;
                        }
                    }
                }
            }

            // then add it to the dest group
            if( groupIndexForInsertion === listCardGroupsModel.count ) {
                createNewGroup(newWindow, groupIndexForInsertion);
            }
            else {
                var destGroup = listCardGroupsModel.get(groupIndexForInsertion);
                destGroup.windowList.insert(destGroup.windowList.count, {"window": newWindow});
            }

            listCardGroupsModel.newCardInserted(groupIndexForInsertion, 0, newWindow);

            // DEBUG: move the new window in the previous group, and build groups of 3 windows
            //if( last>0 && ((last+1)%4) !== 0 )
            //    moveWindowGroup(newWindow, listCardGroupsModel.count-1, listCardGroupsModel.count-2);
        }
    }

    function getCurrentCardOfGroup(group) {
        if( !group ) return null;

        var windowList = group.windowList;
        if( group.currentCardInGroup >= 0 && group.currentCardInGroup < windowList.count ) {
            return windowList.get(group.currentCardInGroup).window;
        }

        return null;
    }

    function setCurrentCardInGroup(group, cardIndexInGroup) {
        group.currentCardInGroup = cardIndexInGroup;
    }

    function setCurrentCard(window) {
        var foundGroupIndex = -1;

        var windowFound = false;
        // First, we have to find which group contains this window
        var groupIndex = 0;
        for( groupIndex=0; !windowFound && groupIndex<listCardGroupsModel.count; ++groupIndex ) {
            var windowList = listCardGroupsModel.get(groupIndex).windowList;
            var windowIndex=0;
            for( windowIndex=0; !windowFound && windowIndex<windowList.count; ++windowIndex ) {
                if( windowList.get(windowIndex).window === window ) {
                    var currentCardInGroup = listCardGroupsModel.get(groupIndex).currentCardInGroup;
                    if( windowIndex !== currentCardInGroup )
                    {
                        listCardGroupsModel.setCurrentCardInGroup(listCardGroupsModel.get(groupIndex), windowIndex);
                    }

                    foundGroupIndex = groupIndex;

                    windowFound = true;
                }
            }
        }

        return foundGroupIndex;
    }

    function setWindowInFront(window, groupIndex) {
        // first, remove the window from the origin group
        var windowList = listCardGroupsModel.get(groupIndex).windowList;
        var i=0;
        for( i=0; i<windowList.count; ++i ) {
            if( windowList.get(i).window === window ) {
                windowList.move(i,windowList.count-1,1);
                break;
            }
        }
    }

    function createNewGroup(window, insertAt) {
        // create a new group with only one window
        listCardGroupsModel.insert(insertAt, {"windowList": [ { "window":window } ], "currentCardInGroup": 0});
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
                    var currentCardInGroup = listCardGroupsModel.get(groupIndex).currentCardInGroup;
                    if( windowIndex === currentCardInGroup )
                    {
                        // if we are going to remove the current card of the group, then
                        // select the previous one
                        listCardGroupsModel.setCurrentCardInGroup(listCardGroupsModel.get(groupIndex), Math.max(currentCardInGroup-1,0));
                    }
                    cardRemoved();
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

