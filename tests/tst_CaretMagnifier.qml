import QtQuick 2.0
import QtTest 1.0
import QtQuick.Window 2.15

import "../qml"

/*
 * The loupe over a selection's end while a finger drags it.
 *
 * The application reports its caret's rectangle - from a web page, the span
 * between the selection's two ends - and the loupe comes up when a drag
 * resizes it, never for a drag that only moves it (scrolling) nor for a press
 * that did not drag (a long press selecting a word).
 */
Item {
    id: root

    width: 480
    height: 800

    // The application's window: a white page with one red letter-sized block
    // at (200, 300) on the line from 290 to 320.
    Rectangle {
        id: appWindow

        anchors.fill: parent
        color: "white"

        Rectangle {
            x: 200
            y: 295
            width: 12
            height: 20
            color: "red"
        }
    }

    // The compositor's input method: the caret's rectangle, already in the
    // loupe's coordinates, or undefined when the application never said.
    QtObject {
        id: inputMethod

        property var caret: undefined
        signal cursorRectangleChanged()

        function cursorRectangleIn(item) {
            return caret;
        }

        function moveCaret(rect) {
            caret = rect;
            cursorRectangleChanged();
        }
    }

    QtObject {
        id: compositor
        property QtObject inputMethod: inputMethod
    }

    CaretMagnifier {
        id: magnifier

        anchors.fill: parent
        compositorInstance: compositor
        editable: true
        foregroundWindow: function() { return appWindow; }
        keyboardRect: Qt.rect(0, 600, 480, 200)
    }

    TestCase {
        name: "CaretMagnifier"
        when: windowShown

        // "quick" selected on the line from 290 to 320.
        readonly property rect word: Qt.rect(130, 290, 60, 30)

        function init() {
            magnifier.editable = true;
            inputMethod.caret = word;
        }

        function cleanup() {
            magnifier.release();
            inputMethod.caret = undefined;
        }

        // The end handle sits under the word's end; dragging it right grows
        // the selection a letter at a time.
        function dragEndHandle() {
            magnifier.press(190, 330);
            magnifier.move(205, 330);
            magnifier.move(215, 330);
            inputMethod.moveCaret(Qt.rect(130, 290, 85, 30));
        }

        function test_up_while_a_handle_is_dragged() {
            dragEndHandle();
            verify(magnifier.visible);
        }

        function test_gone_when_the_finger_lifts() {
            dragEndHandle();
            magnifier.release();
            verify(!magnifier.visible);
        }

        // Scrolling moves the rectangle with the page; nothing is selected by it.
        function test_not_for_a_scroll() {
            magnifier.press(160, 400);
            magnifier.move(160, 360);
            inputMethod.moveCaret(Qt.rect(130, 250, 60, 30));
            magnifier.move(160, 320);
            inputMethod.moveCaret(Qt.rect(130, 210, 60, 30));
            verify(!magnifier.visible);
        }

        // A long press selects the word under a finger that has not moved.
        function test_not_for_a_long_press() {
            inputMethod.caret = Qt.rect(150, 290, 2, 30);
            magnifier.press(160, 305);
            inputMethod.moveCaret(word);
            verify(!magnifier.visible);
        }

        // A finger that has not gone past the slop is still a press.
        function test_not_within_the_slop() {
            magnifier.press(190, 330);
            magnifier.move(194, 331);
            inputMethod.moveCaret(Qt.rect(130, 290, 64, 30));
            verify(!magnifier.visible);
        }

        function test_not_from_the_keyboard() {
            magnifier.press(190, 650);
            magnifier.move(230, 650);
            inputMethod.moveCaret(Qt.rect(130, 290, 85, 30));
            verify(!magnifier.visible);
        }

        function test_not_without_a_field() {
            magnifier.editable = false;
            dragEndHandle();
            verify(!magnifier.visible);
        }

        // Nothing tells where the text is in an application that does not say.
        function test_not_without_a_caret() {
            inputMethod.caret = undefined;
            magnifier.press(190, 330);
            magnifier.move(230, 330);
            inputMethod.moveCaret(undefined);
            verify(!magnifier.visible);
        }

        function test_down_when_the_field_goes() {
            dragEndHandle();
            magnifier.editable = false;
            verify(!magnifier.visible);
            magnifier.editable = true;
            verify(!magnifier.visible);
        }

        // It looks at the line, at the finger's place along it.
        function test_looks_at_the_finger_on_the_line() {
            dragEndHandle();
            compare(magnifier.lookAt.x, 215);
            compare(magnifier.lookAt.y, 305);
        }

        // Past the end of the selection, at its end.
        function test_kept_within_the_selection() {
            dragEndHandle();
            magnifier.move(260, 330);
            compare(magnifier.lookAt.x, 215);
        }

        // Over several lines, the line at the end the finger is at.
        function test_the_line_of_the_end_being_dragged() {
            dragEndHandle();
            magnifier.move(100, 365);
            inputMethod.moveCaret(Qt.rect(20, 290, 300, 60));
            compare(magnifier.lineHeight, 30);
            compare(magnifier.lookAt.y, 335);

            magnifier.move(100, 280);
            compare(magnifier.lookAt.y, 305);
        }

        // Above the line, clear of it, so the finger under it hides nothing.
        function test_above_the_line() {
            dragEndHandle();
            var lens = findChild(magnifier, "caretMagnifierLens");
            verify(lens.above);
            verify(lens.y + lens.height <= 290 - lens.gap + 0.01);
            compare(lens.x + lens.width / 2, 215);
        }

        // With no room above the line, at the top of the screen, over the
        // line, and still above the finger - not under it, where the hand is.
        function test_at_the_top_without_room_above() {
            inputMethod.caret = Qt.rect(130, 10, 60, 30);
            magnifier.press(190, 75);
            magnifier.move(215, 75);
            inputMethod.moveCaret(Qt.rect(130, 10, 85, 30));
            verify(magnifier.visible);

            var lens = findChild(magnifier, "caretMagnifierLens");
            verify(!lens.above);
            verify(lens.y >= 0);
            verify(lens.y < 10, "at the top: " + lens.y);
            verify(lens.y + lens.height < 75, "above the finger: " + (lens.y + lens.height));
        }

        function test_kept_on_the_screen() {
            inputMethod.caret = Qt.rect(400, 290, 60, 30);
            magnifier.press(460, 330);
            magnifier.move(475, 330);
            inputMethod.moveCaret(Qt.rect(400, 290, 75, 30));
            var lens = findChild(magnifier, "caretMagnifierLens");
            verify(lens.x + lens.width <= root.width);
        }

        // Nothing is sampled while it is down, nor during a drag that has
        // not resized anything yet.
        function test_samples_only_while_up() {
            var loader = findChild(magnifier, "caretMagnifierSampleLoader");
            compare(loader.item, null);

            magnifier.press(190, 330);
            magnifier.move(215, 330);
            verify(!magnifier.visible);
            compare(loader.item, null);

            inputMethod.moveCaret(Qt.rect(130, 290, 85, 30));
            compare(findChild(loader.item, "caretMagnifierSample").sourceItem, appWindow);

            magnifier.release();
            compare(loader.item, null);
        }

        // Up a second time, it shows the text again: the sample is not left
        // pointing at the first loupe's texture.
        function test_shows_the_text_each_time() {
            if (GraphicsInfo.api === GraphicsInfo.Software)
                skip("the software renderer draws no ShaderEffectSource; run with QT_QUICK_BACKEND=rhi");

            for (var i = 0; i < 3; ++i) {
                inputMethod.caret = word;
                magnifier.press(190, 330);
                magnifier.move(206, 330);
                inputMethod.moveCaret(Qt.rect(130, 290, 76, 30));
                verify(magnifier.visible);

                var lens = findChild(magnifier, "caretMagnifierLens");
                var cx = Math.round(lens.x + lens.width / 2);
                var cy = Math.round(lens.y + lens.height / 2);
                tryVerify(function() {
                    var c = grabImage(root).pixel(cx, cy);
                    return c.r > 0.8 && c.g < 0.3 && c.b < 0.3;
                }, 2000, "the letter is in loupe " + (i + 1) + "'s middle");

                magnifier.release();
            }
        }

        // The area sampled is the lens over the zoom, centred where it looks.
        function test_samples_around_the_end() {
            dragEndHandle();
            var lens = findChild(magnifier, "caretMagnifierLens");
            var sample = findChild(magnifier, "caretMagnifierSample");
            fuzzyCompare(sample.sourceRect.x + sample.sourceRect.width / 2, 215, 0.01);
            fuzzyCompare(sample.sourceRect.y + sample.sourceRect.height / 2, 305, 0.01);
            fuzzyCompare(sample.sourceRect.width, lens.width / magnifier.zoom, 0.01);
        }

        // And it shows it, larger: the red letter at 200..212 across, seen
        // from 206, is in the loupe's middle and wider than it is on the page.
        function test_shows_the_text_larger() {
            // Qt Quick's software renderer, which the offscreen platform picks
            // unless told otherwise, draws no shader effects at all.
            if (GraphicsInfo.api === GraphicsInfo.Software)
                skip("the software renderer draws no ShaderEffectSource; run with QT_QUICK_BACKEND=rhi");

            magnifier.press(190, 330);
            magnifier.move(206, 330);
            inputMethod.moveCaret(Qt.rect(130, 290, 76, 30));
            verify(magnifier.visible);
            waitForRendering(magnifier);

            var lens = findChild(magnifier, "caretMagnifierLens");
            var cx = Math.round(lens.x + lens.width / 2);
            var cy = Math.round(lens.y + lens.height / 2);
            var isRed = function(c) { return c.r > 0.8 && c.g < 0.3 && c.b < 0.3; };

            // The loupe's first frame can be a frame behind the grab.
            var image = null;
            tryVerify(function() {
                image = grabImage(root);
                return isRed(image.pixel(cx, cy));
            }, 2000, "the letter is in the loupe's middle");

            var red = 0;
            for (var x = Math.round(lens.x) + 4; x < lens.x + lens.width - 4; ++x) {
                if (isRed(image.pixel(x, cy)))
                    ++red;
            }

            verify(red >= 12 * magnifier.zoom - 2, red + " red pixels across, want about " + 12 * magnifier.zoom);
        }
    }
}
