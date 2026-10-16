import Foundation

/// RFC 4180 形式の CSV を UTF-8 バイト列のまま高速に読むパーサー
nonisolated enum CSVParser {
    static func parse(_ data: Data, row handler: ([String]) -> Void) {
        let quote = UInt8(ascii: "\"")
        let comma = UInt8(ascii: ",")
        let cr = UInt8(ascii: "\r")
        let lf = UInt8(ascii: "\n")

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var index = 0
            // UTF-8 BOM を読み飛ばす
            if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
                index = 3
            }

            var row: [String] = []
            var field: [UInt8] = []
            var inQuotes = false
            var rowHasContent = false

            func endField() {
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll(keepingCapacity: true)
            }

            func endRow() {
                endField()
                handler(row)
                row.removeAll(keepingCapacity: true)
                rowHasContent = false
            }

            while index < bytes.count {
                let byte = bytes[index]
                if inQuotes {
                    if byte == quote {
                        if index + 1 < bytes.count, bytes[index + 1] == quote {
                            field.append(quote)
                            index += 1
                        } else {
                            inQuotes = false
                        }
                    } else {
                        field.append(byte)
                    }
                } else {
                    switch byte {
                    case quote:
                        inQuotes = true
                        rowHasContent = true
                    case comma:
                        endField()
                        rowHasContent = true
                    case cr:
                        break
                    case lf:
                        if rowHasContent || !field.isEmpty { endRow() }
                    default:
                        field.append(byte)
                        rowHasContent = true
                    }
                }
                index += 1
            }
            if rowHasContent || !field.isEmpty { endRow() }
        }
    }
}
