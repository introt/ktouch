/*
 *  Copyright 2012  Sebastian Gottfried <sebastiangottfried@web.de>
 *  Copyright 2015  Sebastian Gottfried <sebastiangottfried@web.de>
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

import QtQuick 2.4
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1
import ktouch 1.0
import QtGraphicalEffects 1.0

import "../common"

ColumnLayout {
    id: root
    property Profile profile
    property DataIndexCourse dataIndexCourse
    property KeyboardLayout keyboardLayout
    property alias course: courseItem
    property Lesson selectedLesson: null
    signal lessonSelected(Course course, Lesson lesson)

    function update() {
        if (!course.isValid) return;
        if (!profile) return;
        course.updateLastUnlockedLessonIndex();
        selectLastLesson()
    }

    spacing: 0

    function selectLastLesson() {
        var lessonId = profileDataAccess.courseProgress(profile, course.id, ProfileDataAccess.LastSelectedLesson);
        if (lessonId !== "") {
            for (var index = 0; index < course.lessonCount; index++) {
                if (course.lesson(index).id === lessonId) {
                    root.selectedLesson = course.lesson(index)
                    content.currentIndex = index
                    break
                }
            }
        }
    }

    onProfileChanged: update()

    onDataIndexCourseChanged: {
        root.selectedLesson = null;
        course.update();
        root.update();
    }

    Course {
        id: courseItem
        property int lastUnlockedLessonIndex: -1
        function update() {
            if (root.dataIndexCourse === null) {
                return
            }
            if (dataIndexCourse.id == "custom_lessons") {
                profileDataAccess.loadCustomLessons(root.profile, dataIndexCourse.keyboardLayoutName, courseItem)
            }
            else {
                if (isValid && courseItem.id === dataIndexCourse.id) {
                    return
                }
                dataAccess.loadCourse(dataIndexCourse, courseItem)
            }
        }
        function updateLastUnlockedLessonIndex() {
            lastUnlockedLessonIndex = 0;
            if (profile.skillLevel === Profile.Advanced) {
                lastUnlockedLessonIndex = course.lessonCount - 1;
                return
            }
            var lastUnlockedLessonId = profileDataAccess.courseProgress(profile, course.id, ProfileDataAccess.LastUnlockedLesson);
            if (lastUnlockedLessonId !== "") {
                for (var index = 0; index < course.lessonCount; index++) {
                    lastUnlockedLessonIndex = index
                    if (course.lesson(index).id === lastUnlockedLessonId) {
                        return
                    }
                }
            }
        }
        Component.onCompleted: update()
    }

    StatPopupDialog {
        id: statPopupDialog
        profile: root.profile
        course: course
        lesson: root.selectedLesson
    }

    LessonEditorDialog {
        id: lesseonEditorDialog
        profile: root.profile
        keyboardLayout: root.keyboardLayout
        onClosed: {
            courseItem.update()
            root.update()
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: header.height
        z: 2

        Column {
            id: header
            width: parent.width
            height: toolbar.height + courseDescriptionItem.height

            ToolBar {
                id: toolbar
                width: parent.width

                background: Rectangle {
                    color: toolbarColorScheme.toolbarBackground
                }

                KColorScheme {
                    id: toolbarColorScheme
                    colorGroup: KColorScheme.Active
                    colorSet: KColorScheme.Complementary
                    property color toolbarBackground: Qt.darker(toolbarColorScheme.shade(toolbarColorScheme.hoverDecoration, KColorScheme.MidShade, toolbarColorScheme.contrast, -0.2), 1.5)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    spacing: 5

                    Label {
                        text: root.course? root.course.title: ""
                        font.bold: true
                        color: toolbarColorScheme.normalText
                    }

                    IconToolButton {
                        id: toggleCourseDesciptionButton
                        icon: "help-about"
                        checkable: true
                        color: toolbarColorScheme.normalText
                        backgroundColor: toolbarColorScheme.normalBackground
                        Layout.fillHeight: true
                        Layout.preferredWidth: toolbar.height
                   }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconToolButton {
                        id: configureButton
                        icon: "application-menu"
                        color: toolbarColorScheme.normalText
                        backgroundColor: toolbarColorScheme.normalBackground
                        Layout.fillHeight: true
                        Layout.preferredWidth: toolbar.height
                        onClicked: {
                            var position = mapToItem(null, 0, height)
                            ktouch.showMenu(position.x, position.y)
                        }
                    }
                }
            }

            CourseDescriptionItem {
                id: courseDescriptionItem
                width: parent.width
                active: toggleCourseDesciptionButton.checked
                description: courseItem.description
            }
        }

        DropShadow {
            anchors.fill: header
            source: header
            samples: 16
            horizontalOffset: 0
            verticalOffset: 0
        }
    }

    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
        z: 1

        KColorScheme {
            id: gridColorScheme
            colorGroup: KColorScheme.Active
            colorSet: KColorScheme.View
        }

        Rectangle {
            anchors.fill: parent
            color: gridColorScheme.shade(gridColorScheme.normalBackground, KColorScheme.DarkShade, 1, 0.0)
        }


        GridView {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 20
            clip: true
            focus: true
            property int columns: Math.floor(width / (300 + 20))
            cellWidth: Math.floor(content.width / content.columns)
            cellHeight: Math.round(cellWidth * 2 / 3)

            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    if (root.selectedLesson && content.currentIndex <= course.lastUnlockedLessonIndex) {
                        lessonSelected(course, root.selectedLesson)
                    }
                }
            }

            model: LessonModel {
                id: lessonModel
                course: courseItem
            }

            onCurrentIndexChanged: {
                if (lessonModel.rowCount() > 0) {
                    root.selectedLesson = lessonModel.data(lessonModel.index(currentIndex, 0), LessonModel.DataRole)
                }
                else {
                    root.selectedLesson = null
                }
            }

            delegate: Item {
                id: item
                width: content.cellWidth
                height: content.cellHeight

                LessonSelectorItem {
                    id: lessonItem
                    anchors.fill: parent
                    anchors.topMargin: 10
                    anchors.leftMargin: 0
                    anchors.rightMargin: 20
                    anchors.bottomMargin: 10
                    anchors.centerIn: parent
                    lesson: dataRole
                    selected:  content.currentIndex == index
                    editButtonVisible: course.id == "custom_lessons"
                    onClicked: {
                        item.forceActiveFocus()
                        content.currentIndex = index
                    }

                    onDoubleClicked: {
                        if (index <= course.lastUnlockedLessonIndex) {
                            lessonSelected(course, dataRole)
                        }
                    }
                    onStatButtonClicked: {
                        statPopupDialog.open()
                    }
                    onEditButtonClicked: {
                        lesseonEditorDialog.editLesson(lesson)
                    }
                }

                LessonLockedNotice  {
                    anchors.centerIn: parent
                    visible: index > course.lastUnlockedLessonIndex
                    glowColor: lessonItem.background.color
                }
            }
            ScrollBar.vertical: ScrollBar { }
        }
    }


    Item {
        Layout.fillWidth: true
        height: footer.height
        z: 2

        ToolBar {
            id: footer
            width: parent.width

            KColorScheme {
                id: footerColorScheme
                colorGroup: KColorScheme.Active
                colorSet: KColorScheme.Window
            }

            background: Rectangle {
                color: footerColorScheme.normalBackground
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    height: startButton.implicitHeight

                    IconButton {
                        id: startButton
                        icon: "go-next-view"
                        bgColor: colorScheme.positiveBackground
                        anchors.centerIn: parent
                        text: i18n("Start Training")
                        enabled: root.selectedLesson && content.currentIndex <= course.lastUnlockedLessonIndex
                        onClicked: lessonSelected(course, root.selectedLesson)
                    }
                }
            }

        }

        DropShadow {
            anchors.fill: footer
            source: footer
            samples: 16
            horizontalOffset: 0
            verticalOffset: 0
        }
    }

}
