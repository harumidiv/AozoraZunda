"""App Store 用スクリーンショット撮影のための一時フック（DEBUG-TEMP）。コミットしない"""
from pathlib import Path

SHOT = 'ProcessInfo.processInfo.environment["SHOT"]'


def edit(path, pairs):
    p = Path(path)
    s = p.read_text()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old)
        s = s.replace(old, new)
    p.write_text(s)


edit("AozoraZunda/ContentView.swift", [
    ("    @State private var place = Place.room\n",
     f'    @State private var place = ["map", "shelf", "librarian"].contains({SHOT} ?? "") ? Place.library : Place.room // DEBUG-TEMP\n'
     "    @Environment(LibraryStore.self) private var debugLibrary // DEBUG-TEMP\n"
     "    @Environment(CatalogStore.self) private var debugCatalog // DEBUG-TEMP\n"),
    ("""                CatalogView { go(to: .room) }
                    .transition(.opacity)
            }
        }
""", """                CatalogView { go(to: .room) }
                    .transition(.opacity)
            }
        }
        .task { // DEBUG-TEMP
            guard ProcessInfo.processInfo.environment["SHOT"] != nil, debugLibrary.books.count < 9 else { return } // DEBUG-TEMP
            await debugCatalog.loadIfNeeded() // DEBUG-TEMP
            while debugCatalog.books.isEmpty { try? await Task.sleep(for: .milliseconds(200)) } // DEBUG-TEMP
            for (title, progress) in [("吾輩は猫である", 0.0008), ("羅生門", 0.42), ("蜘蛛の糸", 1.0), ("檸檬", 0.0), ("山月記", 0.15), ("走れメロス", 1.0), ("注文の多い料理店", 0.0), ("銀河鉄道の夜", 0.6), ("坊っちゃん", 0.3)] { // DEBUG-TEMP
                guard let book = debugCatalog.searchTitles(title).first(where: { $0.title == title }) else { continue } // DEBUG-TEMP
                try? await debugLibrary.download(book); debugLibrary.updateProgress(book.id, progress: progress); if progress > 0 { debugLibrary.markOpened(book.id) } // DEBUG-TEMP
            } // DEBUG-TEMP
        } // DEBUG-TEMP
"""),
])

edit("AozoraZunda/Views/LibraryGame/LibraryScene.swift", [
    ("        super.init(columns: 24, rows: 20, playerStart: (12, 16.6))",
     f'        super.init(columns: 24, rows: 20, playerStart: {SHOT} == "map" ? (3, 5.6) : (12, 16.6)) // DEBUG-TEMP'),
])
edit("AozoraZunda/Views/Room/RoomScene.swift", [
    ("        super.init(columns: 12, rows: 11, playerStart: startsAtDoor ? (6, 8.3) : (6, 7))",
     f'        super.init(columns: 12, rows: 11, playerStart: {SHOT} == "room" ? (2.5, 3.6) : startsAtDoor ? (6, 8.3) : (6, 7)) // DEBUG-TEMP'),
])
edit("AozoraZunda/Views/Catalog/CatalogView.swift", [
    ("    @State private var path = NavigationPath()",
     f'    @State private var path = {{ var p = NavigationPath(); if {SHOT} == "shelf" {{ p.append(ShelfRoute(label: "あ", authorID: "000879")) }}; if {SHOT} == "librarian" {{ p.append(SearchRoute()) }}; return p }}() // DEBUG-TEMP'),
])
edit("AozoraZunda/Views/Catalog/BookshelfView.swift", [
    ("""        .navigationDestination(item: $readingBook) { book in
            ReaderView(book: book)
        }
    }""", f"""        .navigationDestination(item: $readingBook) {{ book in
            ReaderView(book: book)
        }}
        .task {{ if {SHOT} == "shelf" {{ try? await Task.sleep(for: .seconds(1)); selection = "book-000879-000128" }} }} // DEBUG-TEMP
    }}"""),
])
edit("AozoraZunda/Views/Catalog/LibrarianView.swift", [
    ("""        .task(id: line) {
            await typeLine()
        }""", f"""        .task(id: line) {{
            await typeLine()
        }}
        .task {{ if {SHOT} == "librarian" {{ while catalog.books.isEmpty {{ try? await Task.sleep(for: .milliseconds(200)) }}; go(.ask(.title)); query = "くもの"; search() }} }} // DEBUG-TEMP"""),
])
edit("AozoraZunda/Views/Library/LibraryView.swift", [
    ("""            .task(id: library.sortedBooks.map(\\.id)) {""", f"""            .task {{ // DEBUG-TEMP
                guard let shot = {SHOT}, ["myshelf", "reader"].contains(shot) else {{ return }} // DEBUG-TEMP
                while library.books.count < 9 {{ try? await Task.sleep(for: .milliseconds(300)) }} // DEBUG-TEMP
                if shot == "myshelf" {{ path.append(MyShelfRoute()) }} // DEBUG-TEMP
                if shot == "reader", let item = library.books.first(where: {{ $0.book.title == "吾輩は猫である" }}) {{ path.append(ReaderRoute(book: item.book)) }} // DEBUG-TEMP
            }} // DEBUG-TEMP
            .task(id: library.sortedBooks.map(\\.id)) {{"""),
])
edit("AozoraZunda/Views/Room/MyShelfView.swift", [
    ("""            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {""", f"""            .scrollIndicators(.hidden)
            .task {{ if {SHOT} == "myshelf" {{ try? await Task.sleep(for: .seconds(1)); selection = items.first {{ if case .book(let b, _) = $0 {{ b.title == "羅生門" }} else {{ false }} }}?.id }} }} // DEBUG-TEMP
            .safeAreaInset(edge: .top) {{"""),
])
edit("AozoraZunda/Views/Reader/ReaderView.swift", [
    ("""            library.markOpened(book.id)
""", f"""            library.markOpened(book.id)
            if {SHOT} == "reader" {{ Task {{ try? await Task.sleep(for: .seconds(3)); readAloud.start(style: .normal) }} }} // DEBUG-TEMP
"""),
])
# 撮影時は ATT ダイアログと広告を出さない
edit("AozoraZunda/AozoraZundaApp.swift", [
    ("            guard phase == .active else { return }\n",
     f"            guard phase == .active, {SHOT} == nil else {{ return }} // DEBUG-TEMP\n"),
])
edit("AozoraZunda/Views/LibraryGame/WalkGameView.swift", [
    ("            if showsBanner {\n                BannerAdView()",
     f"            if showsBanner, {SHOT} == nil {{ // DEBUG-TEMP\n                BannerAdView()"),
])
edit("AozoraZunda/Views/Ads/NativeShelfAdView.swift", [
    ("            if let ad = slot.ad {",
     f"            if let ad = slot.ad, {SHOT} == nil {{ // DEBUG-TEMP"),
])
print("ok")
