/*
 *  Copyright 2012  Sebastian Gottfried <sebastiangottfried@web.de>
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License as
 *  published by the Free Software Foundation; either version 2 of
 *  the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 1.0
import ktouch 1.0

Item {
    id: line
    property string text
    property bool active
    signal done
    signal keyPressed(variant event)
    signal keyReleased(variant event)
    signal newNextChar(string nextChar)

    property string enteredText: ""
    property int position: 0
    property bool isCorrect: true

    focus: true

    onTextChanged: resetLine()

    onFocusChanged: {
        if (!line.activeFocus)
        {
            stats.stopTraining();
        }
    }

    function startTraining() {
        stats.startTraining();
        stopTimer.restart();
    }

    function resetLine() {
        line.enteredText = ""
        line.isCorrect = true
        line.position = 0
        lineChars.model = 0
        lineChars.model = line.text.length
        emitNextChar()
    }

    function deleteLastChar() {
        if (line.position === 0)
            return;
        line.position--;
        var charItem = lineChars.itemAt(line.position);
        charItem.text = line.text.charAt(line.position);
        charItem.state = "placeholder";
        line.enteredText = line.enteredText.substring(0, line.position);
        line.isCorrect = line.enteredText === line.text.substring(0, line.position);
        emitNextChar()
    }

    function addChar(newChar)
    {
        if (line.position >= text.length)
            return;
        var correctChar = text.charAt(line.position);
        var isCorrect = newChar === correctChar;
        var charItem = lineChars.itemAt(line.position);
        line.enteredText += newChar;
        if (line.isCorrect)
        {
            stats.logCharacter(correctChar, isCorrect? TrainingStats.CorrectCharacter: TrainingStats.IncorrectCharacter)
        }
        line.isCorrect = line.isCorrect && isCorrect;
        charItem.text = newChar != " " || isCorrect? newChar: "\u2423";
        charItem.state = line.isCorrect? "done": "error";
        line.position++;
        emitNextChar()
    }

    function emitNextChar()
    {
        if (line.position >= line.text.length)
            newNextChar(null)
        else
            newNextChar(line.text.charAt(line.position))
    }

    Keys.onPressed: {
        if (!line.active)
            return
        cursorAnimation.restart();
        switch(event.key)
        {
        case Qt.Key_Space:
            startTraining();
            if (preferences.nextLineWithSpace && line.position == text.length && line.isCorrect)
            {
                resetLine();
                line.done();
            }
            else
            {
                addChar(event.text.charAt(0))
            }
            break;
        case Qt.Key_Return:
            startTraining();
            if (preferences.nextLineWithReturn && line.position == text.length && line.isCorrect)
            {
                resetLine();
                line.done();
            }
            break;
        case Qt.Key_Backspace:
            startTraining();
            deleteLastChar();
            break;
        case Qt.Key_Delete:
        case Qt.Key_Tab:
            break;
        default:
            startTraining();
            if (event.text !== "")
            {
                addChar(event.text.charAt(0))
            }
            break;
        }
        if (!event.isAutoRepeat)
            line.keyPressed(event)
    }

    Keys.onReleased: {
        if (!line.active)
            return
        if (!event.isAutoRepeat)
            line.keyReleased(event)
    }

    Timer {
        id: stopTimer
        interval: 5000
        onTriggered: {
            stats.stopTraining();
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0
        Repeater {
            id: lineChars
            model: 0
            Text {
                signal error
                id: lineChar
                font.family: "monospace"
                font.pixelSize: fontSize
                transformOrigin: Item.Center
                text: line.text.charAt(index)
                textFormat: Text.PlainText
                state: "placeholder"
                states: [
                    State {
                        name: "placeholder"
                        PropertyChanges {
                            target: lineChar
                            color: "#888"
                        }
                    },
                    State {
                        name: "done"
                        PropertyChanges {
                            target: lineChar
                            color: "#000"
                        }
                    },
                    State {
                        name: "error"
                        PropertyChanges {
                            target: lineChar
                            color: "#f00"
                        }
                    }
                ]
                onStateChanged: {
                    if (lineChar.state == "error")
                        error();
                }

                onError: SequentialAnimation {
                    NumberAnimation {
                        target: lineChar
                        property: "scale"
                        to: 1.3
                        duration: 100
                        easing.type: Easing.OutBack
                        easing.overshoot: 20
                    }
                    NumberAnimation {
                        target: lineChar
                        property: "scale"
                        to: 1.0
                        duration: 50
                        easing.type: Easing.InCubic
                    }
                }
            }
        }
    }
    Rectangle {
        id: cursor
        property Item target: lineChars.itemAt(line.position - 1)
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: (target? target.x + target.width: 0) + row.x
        }
        width: 1
        height: fontSize * 1.2
        color: "#000"
        visible: line.activeFocus
        SequentialAnimation {
            id: cursorAnimation
            running: line.activeFocus && Qt.application.active
            loops: Animation.Infinite
            PropertyAction {
                target: cursor
                property: "opacity"
                value: 1
            }
            PauseAnimation {
                duration: 500
            }
            PropertyAction {
                target: cursor
                property: "opacity"
                value: 0
            }
            PauseAnimation {
                duration: 500
            }
        }

    }

}