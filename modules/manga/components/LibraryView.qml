import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.components
import qs.Ui
import "../../../services/manga_card.js" as MangaCard
import "../../../services/list_metrics.js" as ListMetrics

Item {
    id: libraryView

    readonly property string fontDisplay: Style.font.family
    readonly property string fontBody:    Style.font.family

    // metaLine composes "chapter · status"; the wording lives in
    // manga_card.js, so both views share one adapter instead of copying it.
    readonly property var cardTranslator: MangaCard.translator(I18n.t)

    // One number for the grid and its skeleton: they must not disagree.
    readonly property int columnCount: 3

    // The layout the user picked (persisted in settings.json), shared with
    // Browse through UiPrefs: switching it in one view switches it in both.
    readonly property bool listMode: UiPrefs.viewMode === "list"

    // Emitted when the user taps an entry — parent handles navigation
    signal mangaSelected(string mangaId)

    // One segment of the grid/list toggle: a square glyph chip that shows
    // whether its layout is the one on screen. The hover tooltip carries the
    // name, so the header stays compact.

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Section header (+ grid/list toggle) ──────────────────────────────
        // The library has an exact number (unlike Browse's loaded count).
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.spacing.lg
            Layout.rightMargin: Style.spacing.lg
            spacing: Style.spacing.sm
            visible: Manga.libraryList.length > 0

            PanelSectionHeader {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                fontFamily: libraryView.fontBody
                text: I18n.t("tab.library") + " · " + Manga.libraryList.length
            }

            // Grid/list toggle. Its twin lives in BrowseView.qml: the shared
            // section header is a bare Text in qs.Ui, and giving it children
            // would reach into a component every panel uses.
            ViewModeChip {
                Layout.alignment: Qt.AlignVCenter
                glyph: "▦"
                label: I18n.t("view.grid")
                current: !libraryView.listMode
                bodyFont: libraryView.fontBody
                onClicked: UiPrefs.setViewMode("grid")
            }

            ViewModeChip {
                Layout.alignment: Qt.AlignVCenter
                glyph: "☰"
                label: I18n.t("view.list")
                current: libraryView.listMode
                bodyFont: libraryView.fontBody
                onClicked: UiPrefs.setViewMode("list")
            }
        }

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
            visible: !Manga.libraryLoaded && !libraryView.listMode
            active: !Manga.libraryLoaded && !libraryView.listMode
            // Three columns, like the grid below. The default stays at 4 for
            // the anime and novel libraries, which keep their own 4-column
            // grids; this panel passes its count explicitly.
            columns: libraryView.columnCount
            padding: Style.spacing.lg
            ratio: 1.72
            footerHeight: 30
        }

        // The grid's ghost cards do not apply to a list of rows.
        SkeletonList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            rowHeight: Style.space(ListMetrics.ROW_HEIGHT_BASE)
            dividerInset: Style.spacing.lg
            active: !Manga.libraryLoaded && libraryView.listMode
        }

        GridView {
            id: libGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length > 0 && !libraryView.listMode
            topMargin: Style.spacing.xl
            leftMargin: Style.spacing.lg
            rightMargin: Style.spacing.lg
            bottomMargin: Style.spacing.xl
            cellWidth: Math.floor((width - leftMargin - rightMargin) / libraryView.columnCount)
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
                    // Covers go through the local backend; requesting them
                    // before it is ready fails and Qt keeps that failure for
                    // the session, so wait for the health check.
                    source: Manga.serverReady ? (libEntry.coverUrl || "") : ""
                    title: libEntry.title || ""
                    bodyFont: libraryView.fontBody
                    gradientHeight: 48
                    footerHeight: 30
                    // The work's own metadata, NOT this reader's progress: the
                    // progress bar below keeps "Cap. N" for the user. Today's
                    // entries store no work metadata, so the line stays hidden
                    // rather than inventing it; an entry that carries either
                    // field shows it here.
                    meta: MangaCard.metaLine(libEntry.chapter,
                                             I18n.tData(libEntry.status || ""),
                                             libraryView.cardTranslator)

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

        // ── List ───────────────────────────────────────────────────────────────
        // Same entries, same click path; the reader's progress that the grid
        // pins to the card's footer becomes the row's trailing label.
        ListView {
            id: libRows
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length > 0 && libraryView.listMode
            topMargin: Style.spacing.xl
            bottomMargin: Style.spacing.xl
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Manga.libraryList

            ScrollBar.vertical: StyledScrollBar {
            }

            delegate: ListRow {
                width: libRows.width
                height: implicitHeight
                // The library grid and its header use `lg`; the rows follow.
                inset: Style.spacing.lg

                readonly property var libEntry: modelData

                // Same gate as the grid: the local backend must be up before
                // any cover URL is requested.
                source: Manga.serverReady ? (libEntry.coverUrl || "") : ""
                title: libEntry.title || ""
                bodyFont: libraryView.fontBody
                meta: MangaCard.metaLine(libEntry.chapter,
                                         I18n.tData(libEntry.status || ""),
                                         libraryView.cardTranslator)
                progress: libEntry.lastReadChapterNum
                          ? I18n.t("ch", { 1: libEntry.lastReadChapterNum })
                          : I18n.t("state.notStarted")
                progressActive: !!libEntry.lastReadChapterNum

                onClicked: {
                    Manga.fetchMangaDetail(libEntry.id)
                    libraryView.mangaSelected(libEntry.id)
                }
            }
        }
    }
}
