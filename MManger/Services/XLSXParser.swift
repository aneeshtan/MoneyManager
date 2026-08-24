import Foundation
import Compression

enum XLSXParserError: LocalizedError {
    case notAZipArchive
    case missingWorksheet
    case corruptEntry(String)

    var errorDescription: String? {
        switch self {
        case .notAZipArchive:
            "This file is not a readable .xlsx workbook."
        case .missingWorksheet:
            "The workbook has no readable worksheet."
        case .corruptEntry(let name):
            "Could not read \(name) inside the workbook."
        }
    }
}

/// Reads the first worksheet of an .xlsx workbook into rows of plain strings.
///
/// Only the parts needed for transaction import are decoded (shared strings and the
/// first sheet); styles, formulas, and charts are ignored. Rows are padded so a cell's
/// position in the array always matches its spreadsheet column, because exporters omit
/// empty cells entirely and a naive read would shift every later column left.
enum XLSXParser {
    static func firstSheetRows(from url: URL) throws -> [[String]] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let archive = try ZipArchive(data: data)

        let sharedStrings: [String]
        if let stringsData = try archive.contents(of: "xl/sharedStrings.xml") {
            sharedStrings = SharedStringsXMLParser.parse(stringsData)
        } else {
            sharedStrings = []
        }

        guard let sheetName = archive.firstWorksheetPath(),
              let sheetData = try archive.contents(of: sheetName) else {
            throw XLSXParserError.missingWorksheet
        }

        return WorksheetXMLParser.parse(sheetData, sharedStrings: sharedStrings)
    }

    /// Excel stores dates as days since 1899-12-30. Values below the 1900 leap-year bug
    /// boundary are not worth supporting, so serials under 61 are rejected.
    static func date(fromSerial serial: Double) -> Date? {
        guard serial >= 61, serial < 2_958_466 else { return nil }
        return Date(timeIntervalSince1970: (serial - 25_569) * 86_400)
    }
}

// MARK: - ZIP

/// Minimal read-only ZIP reader for the stored and deflated entries produced by
/// spreadsheet exporters. Sizes and offsets come from the central directory, which is
/// authoritative even when local headers defer them to a trailing data descriptor.
private struct ZipArchive {
    private struct Entry {
        var name: String
        var compressionMethod: UInt16
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]

    init(data: Data) throws {
        self.data = data
        guard let directoryStart = Self.centralDirectoryOffset(in: data) else {
            throw XLSXParserError.notAZipArchive
        }

        var entries: [String: Entry] = [:]
        var cursor = directoryStart
        while cursor + 46 <= data.count, data.readUInt32(at: cursor) == 0x0201_4b50 {
            let nameLength = Int(data.readUInt16(at: cursor + 28))
            let extraLength = Int(data.readUInt16(at: cursor + 30))
            let commentLength = Int(data.readUInt16(at: cursor + 32))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= data.count else { break }

            let name = String(decoding: data[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            let entry = Entry(
                name: name,
                compressionMethod: data.readUInt16(at: cursor + 10),
                compressedSize: Int(data.readUInt32(at: cursor + 20)),
                uncompressedSize: Int(data.readUInt32(at: cursor + 24)),
                localHeaderOffset: Int(data.readUInt32(at: cursor + 42))
            )
            entries[name] = entry
            cursor = nameStart + nameLength + extraLength + commentLength
        }

        guard !entries.isEmpty else { throw XLSXParserError.notAZipArchive }
        self.entries = entries
    }

    func firstWorksheetPath() -> String? {
        entries.keys
            .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .first
    }

    func contents(of name: String) throws -> Data? {
        guard let entry = entries[name] else { return nil }

        let headerStart = entry.localHeaderOffset
        guard headerStart + 30 <= data.count, data.readUInt32(at: headerStart) == 0x0403_4b50 else {
            throw XLSXParserError.corruptEntry(name)
        }
        let nameLength = Int(data.readUInt16(at: headerStart + 26))
        let extraLength = Int(data.readUInt16(at: headerStart + 28))
        let payloadStart = headerStart + 30 + nameLength + extraLength
        let payloadEnd = payloadStart + entry.compressedSize
        guard payloadEnd <= data.count else { throw XLSXParserError.corruptEntry(name) }

        let payload = data[payloadStart..<payloadEnd]
        switch entry.compressionMethod {
        case 0:
            return Data(payload)
        case 8:
            guard let inflated = Self.inflate(Data(payload), expectedSize: entry.uncompressedSize) else {
                throw XLSXParserError.corruptEntry(name)
            }
            return inflated
        default:
            throw XLSXParserError.corruptEntry(name)
        }
    }

    /// ZIP stores raw DEFLATE, which is what `COMPRESSION_ZLIB` decodes on Apple platforms.
    private static func inflate(_ data: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { destination -> Int in
            guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return data.withUnsafeBytes { source -> Int in
                guard let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    destinationBase, expectedSize,
                    sourceBase, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { return nil }
        return output
    }

    /// The end-of-central-directory record sits within the last 64KB plus its own header.
    private static func centralDirectoryOffset(in data: Data) -> Int? {
        let minimumRecord = 22
        guard data.count >= minimumRecord else { return nil }
        let searchStart = max(0, data.count - minimumRecord - 65_535)
        var cursor = data.count - minimumRecord
        while cursor >= searchStart {
            if data.readUInt32(at: cursor) == 0x0605_4b50 {
                return Int(data.readUInt32(at: cursor + 16))
            }
            cursor -= 1
        }
        return nil
    }
}

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        let base = startIndex + offset
        return UInt16(self[base]) | (UInt16(self[base + 1]) << 8)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let base = startIndex + offset
        return UInt32(self[base])
            | (UInt32(self[base + 1]) << 8)
            | (UInt32(self[base + 2]) << 16)
            | (UInt32(self[base + 3]) << 24)
    }
}

// MARK: - XML

private final class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var current = ""
    private var isCollecting = false
    private var phoneticDepth = 0

    static func parse(_ data: Data) -> [String] {
        let delegate = SharedStringsXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "si":
            current = ""
        case "rPh":
            // Phonetic hints duplicate the visible text in some locales; skip them.
            phoneticDepth += 1
        case "t" where phoneticDepth == 0:
            isCollecting = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollecting else { return }
        current += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "si":
            strings.append(current)
            current = ""
        case "rPh":
            phoneticDepth = max(0, phoneticDepth - 1)
        case "t":
            isCollecting = false
        default:
            break
        }
    }
}

private final class WorksheetXMLParser: NSObject, XMLParserDelegate {
    private var sharedStrings: [String] = []
    private var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentColumn = 0
    private var currentType = ""
    private var currentValue = ""
    private var isCollecting = false

    static func parse(_ data: Data, sharedStrings: [String]) -> [[String]] {
        let delegate = WorksheetXMLParser()
        delegate.sharedStrings = sharedStrings
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "row":
            currentRow = []
        case "c":
            currentType = attributes["t"] ?? ""
            currentValue = ""
            currentColumn = attributes["r"].map(Self.columnIndex(fromReference:)) ?? currentRow.count
        case "v", "t":
            isCollecting = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollecting else { return }
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "v", "t":
            isCollecting = false
        case "c":
            let resolved: String
            if currentType == "s", let index = Int(currentValue), sharedStrings.indices.contains(index) {
                resolved = sharedStrings[index]
            } else {
                resolved = currentValue
            }
            while currentRow.count < currentColumn {
                currentRow.append("")
            }
            if currentRow.count == currentColumn {
                currentRow.append(resolved)
            } else {
                currentRow[currentColumn] = resolved
            }
        case "row":
            rows.append(currentRow)
            currentRow = []
        default:
            break
        }
    }

    /// "BC12" -> 54. Trailing row digits are ignored.
    private static func columnIndex(fromReference reference: String) -> Int {
        var index = 0
        for character in reference.uppercased() {
            guard let ascii = character.asciiValue, ascii >= 65, ascii <= 90 else { break }
            index = index * 26 + Int(ascii - 64)
        }
        return max(0, index - 1)
    }
}
