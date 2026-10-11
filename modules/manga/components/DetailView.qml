import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.components

Item {
    id: detailView

    readonly property string fontDisplay: Style.font.family
    readonly property string fontBody:    Style.font.family

    signal backRequested()
    signal chapterSelected(string chapterId)

    // ── Library state ─────────────────────────────────────────────────────────
    readonly property bool _inLibrary:
        Manga.currentManga ? Manga.isInLibrary(Manga.currentManga.id) : false

    // ── Filter / sort state ───────────────────────────────────────────────────
    property bool   _sortAscending:  false
    property string _chapterFilter:  ""

    function reset() {
        _chapterFilter  = ""
        _sortAscending  = false
    }

    // ── Helper ────────────────────────────────────────────────────────────────
    function formatChapter(ch) {
        if (!ch) return "?"
        const match = ch.match(/\d+(\.\d+)?/)
        return match ? match[0] : ch
    }

    // ── Processed (filtered + sorted) chapter list ────────────────────────────
    readonly property var _processedChapters: {
        if (!Manga.currentManga) return []
        let chapters = Manga.currentManga.chapters.slice()

        if (detailView._chapterFilter.trim() !== "") {
            const f = detailView._chapterFilter.trim().toLowerCase()
            chapters = chapters.filter(ch => {
                const num   = detailView.formatChapter(ch.chapter).toLowerCase()
                const title = (ch.title || "").toLowerCase()
                return num.includes(f) || title.includes(f)
            })
        }

        chapters.sort((a, b) => {
            const numA = parseFloat(detailView.formatChapter(a.chapter)) || 0
            const numB = parseFloat(detailView.formatChapter(b.chapter)) || 0
            return detailView._sortAscending ? numA - numB : numB - numA
        })

        return chapters
    }

    // ═════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Colors.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: Style.spacing.md; rightMargin: Style.spacing.xl }
                spacing: Style.spacing.xxs

                // ── Back button ───────────────────────────────────────────────
                Item {
                    width: 44; height: 44

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: height / 2
                        color: backArea.containsMouse ? Colors.surface_container : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "←"; font.pixelSize: Style.font.iconLarge; color: Colors.on_surface_variant
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Manga.clearChapterList(); detailView.backRequested() }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Manga.currentManga ? Manga.currentManga.title : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 15; color: Colors.on_surface; elide: Text.ElideRight // style-ignore — bespoke size
                }

                // ── Library toggle ────────────────────────────────────────────
                Item {
                    visible: Manga.currentManga !== null
                    width: libBtnLabel.implicitWidth + 28
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: detailView._inLibrary ? Colors.primary_container : Colors.surface_container
                        border.color: detailView._inLibrary ? Colors.primary : Colors.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Style.space(5)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detailView._inLibrary ? "✓" : "+"
                            font.pixelSize: Style.font.bodySmall; font.bold: true
                            color: detailView._inLibrary ? Colors.on_primary_container : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: Motion.base } }
                        }
                        StyledText {
                            id: libBtnLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("tab.library")
                            font.family: detailView.fontBody
                            font.pixelSize: Style.font.bodySmall; font.letterSpacing: 0.3
                            color: detailView._inLibrary ? Colors.on_primary_container : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: Motion.base } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary)
                                Manga.removeFromLibrary(Manga.currentManga.id)
                            else
                                Manga.addToLibrary({
                                    id:       Manga.currentManga.id,
                                    title:    Manga.currentManga.title,
                                    coverUrl: Manga.currentManga.coverUrl
                                })
                        }
                    }
                }
            }
        }

        // ── English-only notice ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: Manga.currentManga !== null && Manga.currentManga.language === "en"
            Layout.preferredHeight: visible ? englishNoticeText.implicitHeight + 22 : 0
            color: Colors.error_container
            z: 3

            StyledText {
                id: englishNoticeText
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Style.space(16); rightMargin: Style.space(16)
                }
                text: "⚠  " + I18n.t("manga.englishNotice")
                font.family: detailView.fontBody
                font.pixelSize: Style.font.bodySmall; font.bold: true
                color: Colors.on_error_container
                wrapMode: Text.Wrap
            }
        }

        // ── Hero banner ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Manga.currentManga !== null ? 160 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

            // Blurred cover background
            Image {
                anchors.fill: parent
                source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; opacity: 0.2
            }

            // Gradient overlay
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Colors.withAlpha(Colors.surface_container_low, 0.8) }
                    GradientStop { position: 1.0; color: Colors.background }
                }
            }

            // Content row
            Row {
                anchors { fill: parent; margins: Style.spacing.xxxl }
                spacing: Style.spacing.xxxl

                // Cover thumbnail
                Rectangle {
                    width: 90; height: 130; radius: Style.cornerRadius
                    color: Colors.surface_container_high; clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: Style.cornerRadius; color: "transparent"
                        border.color: Colors.outline_variant; border.width: 1
                    }
                }

                Column {
                    width: parent.width - 104
                    spacing: Style.spacing.md; anchors.verticalCenter: parent.verticalCenter

                    // Status badge
                    Rectangle {
                        visible: Manga.currentManga && Manga.currentManga.status.length > 0
                        height: 18; width: statusText.implicitWidth + 14; radius: height / 2
                        color: Colors.withAlpha(Colors.tertiary, 0.15)
                        border.color: Colors.tertiary; border.width: 1

                        StyledText {
                            id: statusText; anchors.centerIn: parent
                            text: Manga.currentManga ? I18n.tData(Manga.currentManga.status || "").toUpperCase() : ""
                            font.family: detailView.fontBody
                            font.pixelSize: 9; font.letterSpacing: 1.2; font.bold: true // style-ignore — bespoke size
                            color: Colors.tertiary
                        }
                    }

                    // Author
                    StyledText {
                        width: parent.width
                        text: Manga.currentManga ? (Manga.currentManga.authors || []).join(", ") : ""
                        font.family: detailView.fontBody
                        font.pixelSize: Style.font.body; font.bold: true
                        color: Colors.on_surface; elide: Text.ElideRight
                    }

                    // Description
                    StyledText {
                        width: parent.width
                        text: Manga.currentManga ? Manga.currentManga.description : ""
                        font.family: detailView.fontBody; font.pixelSize: Style.font.bodySmall
                        color: Colors.on_surface_variant
                        wrapMode: Text.Wrap; maximumLineCount: 3
                        elide: Text.ElideRight; opacity: 0.8; lineHeight: 1.35
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.35
            }
        }

        // ── Chapter count + last-read strip ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: Colors.surface_container
            visible: Manga.currentManga !== null

            RowLayout {
                anchors { fill: parent; leftMargin: Style.space(16); rightMargin: Style.space(16) }

                StyledText {
                    text: Manga.currentManga ? I18n.tn("count.chapter", Manga.currentManga.chapters.length) : ""
                    font.family: detailView.fontBody
                    font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1
                    color: Colors.on_surface_variant; opacity: 0.75
                }

                Item { Layout.fillWidth: true }

                // Last-read badge
                Rectangle {
                    readonly property var _entry: Manga.currentManga
                        ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastReadChapterNum !== ""
                        && _entry.lastReadChapterNum !== undefined
                    height: 20; width: lastReadText.implicitWidth + 18; radius: height / 2
                    color: Style.selectedFillFor(Colors.primary)
                    border.color: Colors.primary; border.width: 1

                    Text {
                        id: lastReadText; anchors.centerIn: parent
                        text: {
                            var e = Manga.currentManga
                                ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                            return e ? I18n.t("last.ch", { 1: detailView.formatChapter(e.lastReadChapterNum) }) : ""
                        }
                        font.family: detailView.fontBody
                        font.pixelSize: 9; font.letterSpacing: 0.8; color: Colors.primary // style-ignore — bespoke size
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
            }
        }

        // ── Search & Sort bar ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 56
            color: Colors.surface_container_low
            visible: Manga.currentManga !== null

            RowLayout {
                anchors { fill: parent; leftMargin: Style.spacing.xxl; rightMargin: Style.spacing.xxl }
                spacing: Style.spacing.lg

                // Search pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 36; radius: height / 2
                    color: Colors.surface_container
                    border.width: 1
                    border.color: chapterSearch.activeFocus ? Colors.primary : Colors.withAlpha(Colors.outline, 0.2)
                    Behavior on border.color { ColorAnimation { duration: Motion.base } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: Style.spacing.xxl; rightMargin: Style.spacing.sm }
                        spacing: Style.spacing.md

                        StyledText {
                            text: "⌕"
                            font.pixelSize: Style.font.heading
                            color: Colors.primary; opacity: 0.7
                        }

                        TextInput {
                            id: chapterSearch
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            font.family: detailView.fontBody
                            font.pixelSize: Style.font.body
                            color: Colors.on_surface
                            selectionColor: Style.selectionFillFor(Colors.primary)
                            clip: true

                            // Placeholder text
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.t("filterChapters")
                                font.family: detailView.fontBody
                                font.pixelSize: Style.font.body
                                color: Colors.on_surface_variant
                                opacity: 0.45
                                visible: chapterSearch.text === "" && !chapterSearch.activeFocus
                            }

                            onTextChanged: detailView._chapterFilter = text
                        }

                        // Clear button — only shown when there is text
                        Item {
                            width: visible ? 28 : 0; height: 28
                            visible: detailView._chapterFilter !== ""

                            Rectangle {
                                anchors.centerIn: parent
                                width: 22; height: 22; radius: height / 2
                                color: clearArea.containsMouse
                                    ? Style.hoverFillFor(Colors.on_surface)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                            StyledText {
                                anchors.centerIn: parent
                                text: "✕"; font.pixelSize: Style.font.bodySmall
                                color: Colors.on_surface_variant
                            }
                            MouseArea {
                                id: clearArea; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    detailView._chapterFilter = ""
                                    chapterSearch.text = ""
                                }
                            }
                        }
                    }
                }

                // Sort toggle button
                Item {
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: sortArea.containsMouse
                            ? Colors.primary_container
                            : Colors.withAlpha(Colors.primary_container, 0.6)
                        border.color: Colors.primary; border.width: 1
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: detailView._sortAscending ? "↑" : "↓"
                        font.pixelSize: Style.font.heading; font.bold: true
                        color: Colors.on_primary_container
                    }
                    MouseArea {
                        id: sortArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: detailView._sortAscending = !detailView._sortAscending

                        ToolTip.visible: containsMouse
                        ToolTip.delay: 600
                        ToolTip.text: detailView._sortAscending ? I18n.t("sort.ascending") : I18n.t("sort.descending")
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
            }
        }

        // ── Chapter list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Rectangle { anchors.fill: parent; color: Colors.background }

            // Loading overlay
            SkeletonList {
                anchors.fill: parent; z: 5
                active: Manga.isFetchingDetail
                rowHeight: 58
            }

            ListView {
                id: chapterList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: detailView._processedChapters   // ← filtered + sorted

                ScrollBar.vertical: StyledScrollBar {
                }

                delegate: ClickableRect {
                    id: chapterRowAreaRect
                    width: chapterList.width; height: 58

                    readonly property var _libEntry: Manga.currentManga
                        ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    readonly property bool isLastRead:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastReadChapterId === modelData.id

                    color: isLastRead
                        ? Style.selectedFillFor(Colors.primary)
                        : (chapterRowAreaRect.pressed
                            ? Colors.surface_container_high
                            : (chapterRowAreaRect.hovered ? Colors.surface_container : "transparent"))
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left; right: parent.right
                            leftMargin: Style.space(72); rightMargin: Style.space(16)
                        }
                        height: 1; color: Colors.outline_variant; opacity: 0.25
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: Style.space(16); rightMargin: Style.space(16) }
                        spacing: Style.spacing.xxxl

                        // Chapter number pill
                        Rectangle {
                            width: chapterPillText.implicitWidth + 16
                            height: 26; radius: height / 2
                            color: isLastRead ? Colors.primary : Colors.primary_container

                            StyledText {
                                id: chapterPillText; anchors.centerIn: parent
                                text: I18n.t("ch", { 1: detailView.formatChapter(modelData.chapter) })
                                font.family: detailView.fontBody
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5 // style-ignore — bespoke size
                                color: isLastRead ? Colors.on_primary : Colors.on_primary_container
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: Style.spacing.xs

                            Text {
                                width: parent.width
                                text: modelData.title || I18n.t("chapter", { 1: detailView.formatChapter(modelData.chapter) })
                                font.family: detailView.fontBody
                                font.pixelSize: Style.font.body; color: Colors.on_surface; elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.publishAt
                                    ? Qt.formatDate(new Date(modelData.publishAt), "MMM d, yyyy")
                                    : ""
                                font.family: detailView.fontBody
                                font.pixelSize: Style.font.caption; color: Colors.on_surface_variant
                                opacity: 0.55; font.letterSpacing: 0.3
                            }
                        }

                        Text {
                            text: "›"; font.pixelSize: 20; color: Colors.outline // style-ignore — bespoke size
                            opacity: chapterRowAreaRect.hovered ? 0.9 : 0.4
                            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                        }
                    }

                    onClicked: {
                            Manga.fetchChapterPages(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Manga.currentManga && Manga.isInLibrary(Manga.currentManga.id)) {
                                Manga.updateLastRead(
                                    Manga.currentManga.id,
                                    modelData.id,
                                    modelData.chapter
                                )
                            }
                        }
                }
            }
        }
    }
}
