import Foundation

/// 青空文庫の「公開中　作家リスト：全て（拡張版）」CSV を作品一覧に変換する
nonisolated enum AozoraCatalogParser {
    static let catalogURL = URL(string: "https://www.aozora.gr.jp/index_pages/list_person_all_extended_utf8.zip")!

    /// ZIP をダウンロードした生データから作品一覧を作る
    static func parseZip(_ zipData: Data) throws -> [CatalogBook] {
        let csv = try ZipArchive(data: zipData).extractFirst(withExtension: "csv")
        return parseCSV(csv)
    }

    static func parseCSV(_ data: Data) -> [CatalogBook] {
        var header: [String: Int]?
        // 1作品に複数の人物（著者・翻訳者など）の行があるので作品IDでまとめる
        var drafts: [String: Draft] = [:]
        var order: [String] = []

        CSVParser.parse(data) { row in
            guard let columns = header else {
                header = Dictionary(row.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
                return
            }
            func value(_ name: String) -> String {
                guard let index = columns[name], index < row.count else { return "" }
                return row[index]
            }

            let workID = value("作品ID")
            guard !workID.isEmpty else { return }
            let personName = displayName(lastName: value("姓"), firstName: value("名"))
            let role = value("役割フラグ")

            if drafts[workID] == nil {
                let textURLString = value("テキストファイルURL")
                // ZIP で配布されているテキストだけを対象にする
                guard textURLString.lowercased().hasSuffix(".zip"),
                      let textURL = URL(string: textURLString),
                      let cardURL = URL(string: value("図書カードURL"))
                else { return }
                drafts[workID] = Draft(
                    id: workID,
                    title: value("作品名"),
                    titleYomi: value("作品名読み"),
                    titleSortKey: value("ソート用読み"),
                    subtitle: value("副題"),
                    kanaType: value("文字遣い種別"),
                    firstAppearance: value("初出"),
                    cardURL: cardURL,
                    textURL: textURL
                )
                order.append(workID)
            }

            let person = Person(
                id: value("人物ID"),
                name: personName,
                yomi: value("姓読み") + value("名読み"),
                sortKey: value("姓読みソート用") + value("名読みソート用")
            )
            switch role {
            case "著者":
                if drafts[workID]?.author == nil { drafts[workID]?.author = person }
            case "翻訳者":
                drafts[workID]?.translators.append(person.name)
            default:
                if drafts[workID]?.fallbackPerson == nil { drafts[workID]?.fallbackPerson = person }
            }
        }

        return order.compactMap { drafts[$0]?.makeBook() }
    }

    /// 日本人名は「太宰治」、外国人名は「アーヴィング ワシントン」のように表示する
    private static func displayName(lastName: String, firstName: String) -> String {
        guard !lastName.isEmpty, !firstName.isEmpty else { return lastName + firstName }
        let isForeign = lastName.unicodeScalars.contains { scalar in
            (0x30A1...0x30FA).contains(scalar.value) || scalar.isASCII
        }
        return isForeign ? "\(lastName) \(firstName)" : lastName + firstName
    }

    private struct Person {
        let id: String
        let name: String
        let yomi: String
        let sortKey: String
    }

    private struct Draft {
        let id: String
        let title: String
        let titleYomi: String
        let titleSortKey: String
        let subtitle: String
        let kanaType: String
        let firstAppearance: String
        let cardURL: URL
        let textURL: URL
        var author: Person?
        var fallbackPerson: Person?
        var translators: [String] = []

        func makeBook() -> CatalogBook? {
            guard let person = author ?? fallbackPerson else { return nil }
            return CatalogBook(
                id: id,
                title: title,
                titleYomi: titleYomi,
                titleSortKey: titleSortKey,
                subtitle: subtitle,
                authorID: person.id,
                authorName: person.name,
                authorYomi: person.yomi,
                authorSortKey: person.sortKey,
                translatorName: translators.joined(separator: "・"),
                kanaType: kanaType,
                firstAppearance: firstAppearance,
                cardURL: cardURL,
                textURL: textURL
            )
        }
    }
}
