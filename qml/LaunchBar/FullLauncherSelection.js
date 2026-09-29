/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

/*
 * Picking an application in the full launcher with the trackpad.
 *
 * The phone's trackpad is an arrow-key device - it sends Up, Down, Left and
 * Right, nothing else - so this is also what the arrow keys on the keyboard do.
 * Until one of them is pressed there is no selection at all and the launcher
 * looks exactly as it always did; touch is still the first-class way to use it
 * and a highlight sitting on some icon nobody chose would only be in the way.
 *
 * The selection is the grid's own currentIndex, so the delegate can find out
 * whether it is the chosen one with GridView.isCurrentItem, and moving it is a
 * matter of arithmetic on rows and columns. Off the left or right edge of a row
 * the neighbouring tab is a continuation: the selection carries on into it on
 * the same row, which is what makes the whole launcher reachable without ever
 * lifting a finger to the glass.
 *
 * FullLauncher.qml is the only caller, and only of step(), launchSelection()
 * and reset(). Deliberately not a .pragma library: imported this way the file
 * gets its own copy per launcher instance - hence the state below - and reads
 * fullLauncher, tabContentList and flkMouseArea straight out of the document
 * that imports it.
 */

/*
 * One flick of the trackpad is not one keypress.
 *
 * It reports movement as a burst of them: measured on a Q25, a dozen presses a
 * median 24 ms apart (the fastest 8 ms), where two deliberate gestures are
 * 400 ms apart. Acted on one for one, a single flick of the thumb threw the
 * selection clean across the grid and into the next tab - "like it is on
 * steroids". So the first press of a burst moves at once and the rest of that
 * burst is swallowed, which turns a flick into a step or two.
 */
var STEP_INTERVAL_MS = 150;

var lastStepAt = 0;

// Where the selection should land once a tab change has produced a grid to put
// it in: the row it was on, and which edge it is coming in from, since the
// column it ends up in depends on the grid it lands in - see selectInCurrentTab().
var pendingRow = -1;
var pendingFromRight = false;

// Nothing is selected until an arrow is pressed again, and no tab change is
// waiting to be finished either. Called when the launcher is put away.
function reset() {
    fullLauncher.keyboardSelectionActive = false;
    pendingRow = -1;
}

// The grid of the tab on screen. A function rather than a property because
// nothing binds to it: every caller is acting on a keypress and wants to know
// what the launcher is showing at that moment.
function currentGrid() {
    return !!tabContentList.currentItem ? tabContentList.currentItem.launcherGridView : null;
}

// How many icons fit across. The grid is sized to a whole number of cells, so
// this is exact rather than a guess at the layout.
function columnCount() {
    var grid = currentGrid();
    if( !grid || fullLauncher.cellWidth <= 0 ) return 1;
    return Math.max(1, Math.floor(grid.width / fullLauncher.cellWidth));
}

/*
 * One press of an arrow key, burst filter and all. Returns whether the launcher
 * took the press - what it drops it swallows rather than passing on, since the
 * press belongs to a gesture the launcher is already acting on and nothing else
 * should see it either.
 *
 * Auto-repeat is let through the filter untouched: the trackpad never sends it
 * (126 presses in that capture, not one of them a repeat), so it can only be a
 * keyboard arrow being held down, and somebody holding an arrow down is asking
 * to keep moving.
 */
function step(dx, dy, isAutoRepeat) {
    if( !isAutoRepeat ) {
        var now = Date.now();
        if( now - lastStepAt < STEP_INTERVAL_MS )
            return true;
        lastStepAt = now;
    }

    return handleArrow(dx, dy);
}

/*
 * The first press only brings the selection out, wherever the grid's index
 * happens to be, because a press that both revealed the highlight and moved it
 * would leave the user guessing where it came from.
 */
function handleArrow(dx, dy) {
    var grid = currentGrid();

    // A tab with no icons in it - Favourites, until something is put there -
    // has nothing to select, so left and right carry straight on through it to
    // the next tab. Without this it was a dead end: nothing to move, and no way
    // back out again either.
    if( !grid || grid.count <= 0 )
        return dx !== 0 ? stepToTab(dx, 0) : true;

    if( !fullLauncher.keyboardSelectionActive ) {
        fullLauncher.keyboardSelectionActive = true;
        grid.currentIndex = Math.max(0, Math.min(grid.currentIndex, grid.count - 1));
        ensureSelectionVisible();
        return true;
    }

    if( fullLauncher.isEditionActive )
        return moveSelectedIcon(dx, dy);

    return moveSelection(dx, dy);
}

function moveSelection(dx, dy) {
    var grid = currentGrid();
    var columns = columnCount();
    var index = grid.currentIndex;
    var column = index % columns;
    var row = Math.floor(index / columns);

    if( dy !== 0 ) {
        // Clamped rather than wrapped: the last row is rarely full, and landing
        // on a different column than the one you came down is worse than
        // stopping.
        var wantedRow = row + dy;
        if( wantedRow < 0 ) return true;
        var wantedIndex = wantedRow * columns + column;
        if( wantedIndex >= grid.count ) {
            if( row * columns + columns - 1 >= grid.count - 1 ) return true; // already on the last row
            wantedIndex = grid.count - 1;
        }
        grid.currentIndex = wantedIndex;
        ensureSelectionVisible();
        return true;
    }

    var nextColumn = column + dx;
    if( nextColumn >= 0 && nextColumn < columns && index + dx < grid.count ) {
        grid.currentIndex = index + dx;
        ensureSelectionVisible();
        return true;
    }

    // Off the edge of the row: the next tab takes over, on the same row.
    return stepToTab(dx, row);
}

function stepToTab(dx, row) {
    var wantedTab = tabContentList.currentIndex + dx;
    if( wantedTab < 0 || wantedTab >= tabContentList.count ) return true; // no such tab, stay put

    // Coming off the right edge we arrive at the left one and the other way
    // round, so that the icons read as one continuous row across the tabs.
    pendingRow = row;
    pendingFromRight = dx < 0;
    tabContentList.currentIndex = wantedTab;

    // The tab's delegate may only exist once the view has caught up with the new
    // index, so place the selection on the next turn of the event loop.
    Qt.callLater(selectInCurrentTab);
    return true;
}

function selectInCurrentTab() {
    var grid = currentGrid();
    if( !grid || pendingRow < 0 ) return;

    var columns = columnCount();
    var wanted = pendingRow * columns + (pendingFromRight ? columns - 1 : 0);
    pendingRow = -1;

    if( grid.count <= 0 ) return; // an empty tab: nothing to put the selection on

    grid.currentIndex = Math.max(0, Math.min(wanted, grid.count - 1));
    ensureSelectionVisible();
}

// In edition mode the arrows carry the icon instead of leaving it behind.
// Within its own tab only: a tab is a whole page here, and sliding an icon off
// the edge into one the user cannot see while doing it is what the drag has tab
// drop areas for.
function moveSelectedIcon(dx, dy) {
    var grid = currentGrid();
    var columns = columnCount();
    var from = grid.currentIndex;
    var to = from + (dy !== 0 ? dy * columns : dx);

    if( to < 0 || to >= grid.count || from === to ) return true;

    grid.model.move(from, to, 1);
    grid.currentIndex = to;
    ensureSelectionVisible();
    return true;
}

// The grid's own contentY is bound to the flickable that scrolls it, so
// scrolling means moving the flickable and letting the binding follow.
function ensureSelectionVisible() {
    var grid = currentGrid();
    if( !grid || flkMouseArea.height <= 0 ) return;

    var top = Math.floor(grid.currentIndex / columnCount()) * fullLauncher.cellHeight;
    var bottom = top + fullLauncher.cellHeight;
    var wantedY = flkMouseArea.contentY;

    if( top < wantedY )
        wantedY = top;
    else if( bottom > wantedY + flkMouseArea.height )
        wantedY = bottom - flkMouseArea.height;

    flkMouseArea.contentY = Math.max(0, Math.min(wantedY,
                                Math.max(0, flkMouseArea.contentHeight - flkMouseArea.height)));
}

// Enter, Return or Space on the selected icon.
function launchSelection() {
    if( !fullLauncher.keyboardSelectionActive || fullLauncher.isEditionActive ) return false;

    var grid = currentGrid();
    if( !grid || !grid.currentItem ) return false;

    fullLauncher.startLaunchApplication(grid.currentItem.modelId, grid.currentItem.modelParams);
    return true;
}
