/* There are only 3 functions that should be used from this library:

  *** dumpTree(root)
  Will produce a nicely indented visualization of the QML tree starting at any arbitrary root item

  *** dumpFocusTree(root, view)
  Like the above, but only prints items that are focus scopes.
  To make this work you need to have in whatever C++ object you pass into view a method like this:

    bool SomeClass::itemIsFocusScope(QDeclarativeItem* item)
    {
        if (qobject_cast<QGraphicsItem*>(item) == NULL) return false;
        return (item->flags() & QGraphicsItem::ItemIsFocusScope);
    }

  *** focusPath(root)
  Will iterate the entire object tree starting at root, find whatever item has the current activeFocus
  and then print it plus an indented tree of his ancestors.
  Please note that it may happen that there's currently no item with activeFocus and this function
  will correctly report that.
  I use to run this latter function in a periodic timer, to know where the focus is at any specific
  moment (since there's no signal from the view that can tell us when it changes. it would be nice though).

*/

.pragma library

function pad(n) {
    var out = ""
    for (var k = 0; k < n; k++) out += "  "
    return out;
}

function itemName(item) {
    if (item.toString().indexOf("QDeclarativeLoader") == 0 ||item.toString().indexOf("QDeclarativeImage") == 0) {
        var src = item.source.toString()
        return "" + item + " " + src.substring(src.length - 25)
    }
    else return item.toString()
}

function iterateFocusStack(item, path) {
    for (var i = 0; i < item.children.length; i++) {
        if (iterateFocusStack(item.children[i], path)) {
            path.push(itemName(item.children[i]))
            return true;
        }
    }
    return item.activeFocus;
}

function focusPath(root) {
    console.log("<< FOCUS PATH >>")
    var path = []
    iterateFocusStack(root, path);
    if (path.length > 0) path.push(itemName(root));
    for (var i = path.length - 1; i >= 0; i--) {
        console.log(pad(path.length - i - 1) + path[i])
    }
    console.log("<< END >>"); console.log("");
}

function dumpTree(item, level) {
    if (level === undefined) level = 0
    console.log(pad(level) + itemName(item))
    for (var i = 0; i < item.children.length; i++) {
        dumpTree(item.children[i], level + 1);
    }
}

function dumpFocusTree(item, view, level) {
    if (level === undefined) level = 0
    if (view === undefined || view.itemIsFocusScope(item)) console.log(pad(level) + itemName(item) +
                                                 (item.focus ? " FOCUS" : "") +
                                                 (item.activeFocus ? " ACTIVE" : ""))
    for (var i = 0; i < item.children.length; i++) {
        dumpFocusTree(item.children[i], view, level + 1);
    }
}
