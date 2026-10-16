import Compression
import Foundation

/// 青空文庫の配布ZIPを展開するための最小限のZIPリーダー（無圧縮 / Deflate のみ対応）
nonisolated struct ZipArchive {
    struct Entry {
        let fileName: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    enum ZipError: LocalizedError {
        case invalidArchive
        case unsupportedMethod(UInt16)
        case decompressionFailed
        case entryNotFound

        var errorDescription: String? {
            switch self {
            case .invalidArchive: "ZIPファイルの形式が不正です"
            case .unsupportedMethod(let method): "未対応の圧縮形式です (\(method))"
            case .decompressionFailed: "ZIPファイルの展開に失敗しました"
            case .entryNotFound: "ZIPファイル内に目的のファイルが見つかりません"
            }
        }
    }

    let entries: [Entry]
    private let bytes: [UInt8]

    init(data: Data) throws {
        bytes = [UInt8](data)
        entries = try Self.readCentralDirectory(bytes)
    }

    /// 指定した拡張子を持つ最初のエントリを展開する
    func extractFirst(withExtension ext: String) throws -> Data {
        let suffix = "." + ext.lowercased()
        guard let entry = entries.first(where: { $0.fileName.lowercased().hasSuffix(suffix) }) else {
            throw ZipError.entryNotFound
        }
        return try extract(entry)
    }

    func extract(_ entry: Entry) throws -> Data {
        let headerOffset = entry.localHeaderOffset
        guard headerOffset + 30 <= bytes.count, readUInt32(bytes, headerOffset) == 0x0403_4b50 else {
            throw ZipError.invalidArchive
        }
        let nameLength = Int(readUInt16(bytes, headerOffset + 26))
        let extraLength = Int(readUInt16(bytes, headerOffset + 28))
        let start = headerOffset + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard end <= bytes.count else { throw ZipError.invalidArchive }

        switch entry.method {
        case 0:
            return Data(bytes[start..<end])
        case 8:
            return try inflate(start: start, count: entry.compressedSize, uncompressedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupportedMethod(entry.method)
        }
    }

    private func inflate(start: Int, count: Int, uncompressedSize: Int) throws -> Data {
        if uncompressedSize == 0 { return Data() }
        var output = Data(count: uncompressedSize)
        let written = bytes.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBytes { destination in
                // COMPRESSION_ZLIB は raw deflate（ZIPの圧縮データ形式）を扱う
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, uncompressedSize,
                    source.baseAddress! + start, count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == uncompressedSize else { throw ZipError.decompressionFailed }
        return output
    }

    private static func readCentralDirectory(_ bytes: [UInt8]) throws -> [Entry] {
        // End of Central Directory レコードを末尾から探す
        let minimumEOCDSize = 22
        guard bytes.count >= minimumEOCDSize else { throw ZipError.invalidArchive }
        let searchLowerBound = max(0, bytes.count - minimumEOCDSize - 0xFFFF)
        var eocdOffset: Int?
        var index = bytes.count - minimumEOCDSize
        while index >= searchLowerBound {
            if readUInt32(bytes, index) == 0x0605_4b50 {
                eocdOffset = index
                break
            }
            index -= 1
        }
        guard let eocdOffset else { throw ZipError.invalidArchive }

        let entryCount = Int(readUInt16(bytes, eocdOffset + 10))
        var offset = Int(readUInt32(bytes, eocdOffset + 16))
        var entries: [Entry] = []
        entries.reserveCapacity(entryCount)

        for _ in 0..<entryCount {
            guard offset + 46 <= bytes.count, readUInt32(bytes, offset) == 0x0201_4b50 else {
                throw ZipError.invalidArchive
            }
            let method = readUInt16(bytes, offset + 10)
            let compressedSize = Int(readUInt32(bytes, offset + 20))
            let uncompressedSize = Int(readUInt32(bytes, offset + 24))
            let nameLength = Int(readUInt16(bytes, offset + 28))
            let extraLength = Int(readUInt16(bytes, offset + 30))
            let commentLength = Int(readUInt16(bytes, offset + 32))
            let localHeaderOffset = Int(readUInt32(bytes, offset + 42))
            let nameStart = offset + 46
            guard nameStart + nameLength <= bytes.count else { throw ZipError.invalidArchive }
            let fileName = String(decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)

            entries.append(Entry(
                fileName: fileName,
                method: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }
}

nonisolated private func readUInt16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
}

nonisolated private func readUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
}
