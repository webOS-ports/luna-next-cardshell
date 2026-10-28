import QtQuick 2.0

import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

import "../DockMode"

/*
 * The CardGroupModel describes how the cards are organized into groups.
 * Each group corresponds to a ListElement of the ListModel, and contains
 * the list of the windows it aggregates.
 * A group is visualized with the CardGroupDelegate delegate.
 */

ListModel {
    id: listCardGroupsModel

    signal newCardInserted(int group, int index, Item newWindow)
    signal cardRemoved(Item window)

    //! The group the card view has in the middle, if any: a new card's group
    //! goes right after it, as LunaSysMgr's did (CardWindowManager::
    //! prepareAddWindowSibling), and at the end when there is none.
    property int activeGroupIndex: -1

    property WindowModel listCardsModel: WindowModel {
        surfaceSource: compositor.surfaceModel
        windowType: "_WEBOS_WINDOW_TYPE_CARD"
        // An acceptFunction replaces the windowType test entirely, so the
        // card check has to be repeated here. Windows exhibition mode is
        // hosting are left out, so a docked application doesn't also sit in
        // the card stack behind it.
        acceptFunction: "acceptCard"

        function acceptCard(surfaceItem) {
            return surfaceItem.type === "_WEBOS_WINDOW_TYPE_CARD" &&
                   !ExhibitionState.isExhibitionWindow(surfaceItem);
        }

        // Re-run the filter whenever exhibition mode takes or releases an
        // app. invalidateFilter() isn't callable from QML, but toggling
        // locked re-filters on the way back out, which is public API.
        property int exhibitionRevision: ExhibitionState.revision
        onExhibitionRevisionChanged: {
            listCardsModel.locked = true;
            listCardsModel.locked = false;
        }

        onRowsAboutToBeRemoved: (index, first, last) => {
            for( var i = first; i <= last; ++i )
                removeWindow(listCardsModel.get(i));
        }
        onRowsInserted: (index, first, last) => {
            for( var i = first; i <= last; ++i )
                addWindow(listCardsModel.get(i));
        }
    }

    /*
     * Every window is in exactly one group, and there are no empty groups.
     * Windows are found by identity, never through a cached index or a
     * DelegateModel item, which go stale as soon as the model changes.
     */

    //! { group, card } of the window, or null
    function find(window) {
        if( !window ) return null;
        for( var g = 0; g < count; ++g ) {
            var windowList = get(g).windowList;
            for( var c = 0; c < windowList.count; ++c ) {
                if( windowList.get(c).window === window )
                    return { "group": g, "card": c };
            }
        }
        return null;
    }

    function addWindow(newWindow) {
        if( !newWindow || find(newWindow) ) return;

        var groupIndex = -1;
        // A child window joins its parent's group, on top of it.
        if( newWindow.parentWinId ) {
            for( var g = 0; groupIndex < 0 && g < count; ++g ) {
                var windowList = get(g).windowList;
                for( var c = 0; c < windowList.count; ++c ) {
                    if( windowList.get(c).window.winId === newWindow.parentWinId ) {
                        groupIndex = g;
                        break;
                    }
                }
            }
        }

        var cardIndex = 0;
        if( groupIndex >= 0 ) {
            var group = get(groupIndex);
            cardIndex = group.windowList.count;
            group.windowList.append({"window": newWindow});
            group.currentCardInGroup = cardIndex;
        }
        else {
            groupIndex = (activeGroupIndex >= 0 && activeGroupIndex < count) ? activeGroupIndex + 1 : count;
            createNewGroup(newWindow, groupIndex);
        }

        newCardInserted(groupIndex, cardIndex, newWindow);
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

    //! Make the window the current card of its group; returns the group's index, or -1
    function setCurrentCard(window) {
        var pos = find(window);
        if( !pos ) return -1;
        setCurrentCardInGroup(get(pos.group), pos.card);
        return pos.group;
    }

    function createNewGroup(window, insertAt) {
        // create a new group with only one window
        insert(insertAt, {"windowList": [], "currentCardInGroup": 0, "spreadRatio": 0.1});
        get(insertAt).windowList.append( { "window":window } );
    }

    // Take the window out of its group and fix the group's current card up;
    // the group itself is left in place even when it is now empty.
    //! Take the window at pos out of its group; returns true if that
    //! emptied the group, which is then removed as a whole: emptied first,
    //! its delegate would lay out a group of no cards on its way out.
    function __takeWindow(pos) {
        var group = get(pos.group);
        if( group.windowList.count === 1 ) {
            remove(pos.group);
            return true;
        }
        var current = group.currentCardInGroup;
        group.windowList.remove(pos.card);
        if( pos.card < current )
            current = current - 1;
        else if( pos.card === current )
            // LunaSysMgr made the card on the left the active one (CardGroup::removeFromGroup)
            current = Math.max(pos.card - 1, 0);
        group.currentCardInGroup = Math.min(current, Math.max(group.windowList.count - 1, 0));
        return false;
    }

    function removeWindow(window) {
        var pos = find(window);
        if( !pos ) return;

        __takeWindow(pos);
        cardRemoved(window);
    }

    //! Move the window to position cardIndex of group groupIndex; both are
    //! counted as they are before the move. The window becomes the current
    //! card of that group. An emptied group is removed.
    function moveWindow(window, groupIndex, cardIndex) {
        var pos = find(window);
        if( !pos || groupIndex < 0 || groupIndex >= count ) return false;

        var target = get(groupIndex);
        cardIndex = Math.max(0, Math.min(cardIndex, target.windowList.count));

        if( pos.group === groupIndex ) {
            var to = cardIndex > pos.card ? cardIndex - 1 : cardIndex;
            if( to !== pos.card )
                target.windowList.move(pos.card, to, 1);
            target.currentCardInGroup = to;
            return true;
        }

        target.windowList.insert(cardIndex, {"window": window});
        target.currentCardInGroup = cardIndex;
        __takeWindow(pos);
        return true;
    }

    //! Move the window into a group of its own at groupIndex, counted as
    //! before the move. Returns the new group's index.
    function moveWindowToNewGroup(window, groupIndex) {
        var pos = find(window);
        if( !pos ) return -1;
        groupIndex = Math.max(0, Math.min(groupIndex, count));

        // Already alone, and that is where it would go
        if( get(pos.group).windowList.count === 1 &&
            (groupIndex === pos.group || groupIndex === pos.group + 1) )
            return pos.group;

        createNewGroup(window, groupIndex);
        if( groupIndex <= pos.group )
            pos.group = pos.group + 1;
        if( __takeWindow(pos) && pos.group < groupIndex )
            groupIndex = groupIndex - 1;
        return groupIndex;
    }
}
