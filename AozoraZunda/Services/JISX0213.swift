import Foundation

/// 外字注記の面区点番号（例: 1-85-7）を Unicode 文字に変換する
nonisolated enum JISX0213 {
    private static let table: [String: String] = {
        guard let url = Bundle.main.url(forResource: "jisx0213", withExtension: "tsv"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }
        var table: [String: String] = [:]
        table.reserveCapacity(18_000)
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            table[String(parts[0])] = String(parts[1])
        }
        return table
    }()

    static func character(plane: Int, row: Int, cell: Int) -> String? {
        table["\(plane)-\(row)-\(cell)"]
    }
}
