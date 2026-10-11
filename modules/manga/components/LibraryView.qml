import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.components

Item {
    id: libraryView

    readonly property string fontDisplay: Style.font.family
    readonly property string fontBody:    Style.font.family

    // Emitted when the user taps an entry — parent handles navigation
    signal mangaSelected(string mangaId)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Empty state ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length === 0 && Manga.libraryLoaded

            EmptyState {
                title: I18n.t("empty.library")
                subtitle: I18n.t("manga.library.hint")
                displayFont: libraryView.fontDisplay
                bodyFont: libraryView.fontBody
            }
        }

        // ── Loading (first open before file is read) ──────────────────────────
        SkeletonGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Manga.libraryLoaded
            active: !Manga.libraryLoaded
            padding: Style.spacing.lg
            ratio: 1.72
            footerHeight: 30
        }

        GridView {
            id: libGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length > 0
            topMargin: Style.spacing.xl
            leftMargin: Style.spacing.lg
            rightMargin: Style.spacing.lg
            bottomMargin: Style.spacing.xl
            cellWidth: Math.floor((width - leftMargin - rightMargin) / 4)
            cellHeight: cellWidth * 1.72
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Manga.libraryList

            ScrollBar.vertical: StyledScrollBar {
            }

            delegate: Item {
                width: libGrid.cellWidth
                height: libGrid.cellHeight

                readonly property var libEntry: modelData

                CoverCard {
                    anchors.fill: parent
                    source: libEntry.coverUrl || ""
                    title: libEntry.title || ""
                    bodyFont: libraryView.fontBody
                    gradientHeight: 48
                    footerHeight: 30

                    CoverProgressBar {
                        height: 30
                        rowSpacing: Style.spacing.md
                        bodyFont: libraryView.fontBody
                        started: libEntry.lastReadChapterNum
                        label: libEntry.lastReadChapterNum
                                ? I18n.t("ch", { 1: libEntry.lastReadChapterNum })
                                : I18n.t("state.notStarted")
                    }

                    onClicked: {
                        Manga.fetchMangaDetail(libEntry.id)
                        libraryView.mangaSelected(libEntry.id)
                    }
                }
            }
        }
    }
}
