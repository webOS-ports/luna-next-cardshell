import QtQuick
import QtTest 1.0
import QtQuick.Window

/*
 * The attached Window.width, Window.height and Window.window read as undefined
 * in a file that imports QtQuick 2.0. CardShell.qml does, and sized its
 * GestureHandler from Window.width/height: the handler stayed 0x0, every touch
 * counted as a screen-edge touch, and every touch held the rotation until it
 * was lifted.
 *
 * For each shell file that uses those attached properties, build an item with
 * that file's own QtQuick and QtQuick.Window imports, read Window the way the
 * file does (through its alias, if it has one), and check the values.
 */
TestCase {
    name: "WindowAttachedImport"
    width: 300
    height: 200
    when: windowShown

    Item { id: host; anchors.fill: parent }

    function source(file) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../qml/" + file), false);
        xhr.send();
        return xhr.responseText;
    }

    function test_attached_window_properties_data() {
        return [
            { tag: "CardShell.qml", file: "CardShell.qml" },
            { tag: "OrientationHelper.qml", file: "OrientationHelper.qml" },
            { tag: "EinkRefresh.qml", file: "Connectors/EinkRefresh.qml" },
        ];
    }

    function test_attached_window_properties(data) {
        var text = source(data.file);
        var quick = text.match(/^import QtQuick( [0-9.]+)?$/m);
        var win = text.match(/^import QtQuick\.Window( [0-9.]+)?( as (\w+))?$/m);
        verify(quick !== null, data.file + " imports QtQuick");
        verify(win !== null, data.file + " imports QtQuick.Window");
        var w = (win[3] ? win[3] + "." : "") + "Window";
        var item = Qt.createQmlObject(quick[0] + "\n" + win[0] + "\n" +
            "Item { property var w: " + w + ".width; property var h: " + w + ".height; " +
            "property var win: " + w + ".window }", host, data.file);
        var imports = quick[0] + " / " + win[0];
        compare(item.win, host.Window.window, imports + ": " + w + ".window");
        compare(item.w, host.Window.window.width, imports + ": " + w + ".width");
        compare(item.h, host.Window.window.height, imports + ": " + w + ".height");
        item.destroy();
    }
}
