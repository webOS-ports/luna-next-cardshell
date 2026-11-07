import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * CardDismissHint: the title, the words and OK, inside the screen and
 * apart, and OK taking it away.
 */
TestCase {
    id: test
    name: "CardDismissHint"
    when: windowShown
    visible: true
    width: 480
    height: 800

    CardDismissHint {
        id: hint
    }

    function find(objectName, item) {
        if (!item)
            return null;
        if (item.objectName === objectName)
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var found = find(objectName, kids[i]);
            if (found)
                return found;
        }
        return null;
    }

    function test_openAndOk() {
        verify(!hint.visible, "not up until asked");
        hint.open();
        verify(hint.visible);
        compare(hint.title, "Dismissing Cards");
        verify(hint.message.indexOf("flick its card up") >= 0, hint.message);
        verify(hint.dialogWidth <= test.width, "as wide as the screen at most");
        verify(hint.frameHeight >= hint.fittedHeight - 0.5, "tall enough for what is in it");

        var ok = find("cardDismissHintOk", hint);
        verify(ok !== null, "OK");
        var box = ok.mapToItem(test, 0, 0, ok.width, ok.height);
        verify(box.x >= 0 && box.x + box.width <= test.width, "OK across the screen");
        verify(box.y >= 0 && box.y + box.height <= test.height, "OK on the screen");
        waitForRendering(hint);
        mouseClick(ok);
        verify(!hint.visible, "OK took it away");
    }
}
