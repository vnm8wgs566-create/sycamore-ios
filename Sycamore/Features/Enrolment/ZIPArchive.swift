//
//  ZIPArchive.swift
//  Sycamore
//
//  Enough of a ZIP reader to open an `.xlsx`, which is a ZIP of XML and nothing else.
//
//  This exists because of two facts that meet here. The office sends Excel files, and
//  **this project takes no third-party dependencies** — so `ZIPFoundation` and its cousins are
//  not on the table. And `Foundation` has no unzip: `NSFileCoordinator`, `FileManager` and
//  `Data` between them cannot see inside an archive. What the platform *does* give is
//  `Compression`, which inflates a raw DEFLATE stream, and DEFLATE is the only compression a
//  spreadsheet ever uses. So the container is walked here by hand and the payload is handed to
//  the system.
//
//  Read through the **central directory** rather than by walking local headers front to back.
//  The central directory is the archive's index — it is the only place a ZIP is required to
//  state a member's real compressed and uncompressed sizes. A local header may legally carry
//  zeros for both and put the true numbers in a data descriptor *after* the payload (general
//  purpose bit 3, which is what a streaming writer sets), so a front-to-back walk has to guess
//  where one member ends and the next begins. Reading the index means never guessing.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT THIS DELIBERATELY DOES NOT DO
//  ---------------------------------------------------------------------------------------------
//
//  - **ZIP64.** Detected and refused rather than mis-read: the 32-bit fields saturate at
//    `0xFFFF_FFFF` and the real values move into an extra field this does not parse. A roster
//    that reaches 4 GB is not a roster, so refusing is the honest answer.
//  - **Encryption.** An encrypted member sets general purpose bit 0. Inflating it would produce
//    noise that the XML parser would then reject with a confusing message, so it is refused here
//    where the reason is still known.
//  - **CRC-32.** Not checked. `compression_decode_buffer` already fails on a stream that does not
//    inflate, and a payload that inflates cleanly to the stated length but is wrong anyway is not
//    a failure a checksum would save us from — it would still have to survive `XMLParser`.
//    Stated rather than silently omitted, because "does not verify integrity" is a real property
//    of this type.
//  - **Directory entries, symlinks, multi-disk archives.** An `.xlsx` has none. A member whose
//    name ends in `/` is simply never asked for.
//
//  Bytes are held as `[UInt8]` rather than as `Data`. `Data`'s indices are not guaranteed to
//  start at zero — a slice keeps its parent's — and every offset in a ZIP is measured from the
//  start of the file, so one `Data(contentsOf:)` that happened to arrive as a slice would read
//  every header at the wrong place. An array's indices always start at zero.
//

import Compression
import Foundation

/// A ZIP archive, read from memory, opened by member name.
struct ZIPArchive {

    enum ReadError: Error, Equatable {
        /// No end-of-central-directory record. Not a ZIP at all — an `.xls`, a PDF, or a
        /// download that stopped early.
        case notAZIP
        /// A header runs off the end of the bytes.
        case truncated
        /// Stored and deflated are the two a spreadsheet uses. The method number rides along for
        /// whoever is standing in a debugger — nothing surfaces it, because every one of these
        /// becomes the same sentence by the time a person sees it.
        case unsupportedCompression(UInt16)
        /// See the header — the sizes have moved somewhere this does not look.
        case zip64
        case encrypted
        /// A member claiming to inflate to more than `sizeLimit`. Refused before the buffer is
        /// allocated rather than after: the size is the *file's* number, and a 12 KB archive is
        /// allowed to claim four gigabytes.
        case entryTooLarge(String)
        /// The member is there and its payload will not inflate.
        case corruptEntry(String)
    }

    // MARK: Signatures

    /// Internal rather than private so the test fixture that *writes* an archive can spell these
    /// the same way the reader that opens one does. A magic number the writer and the reader hold
    /// separate copies of is a magic number they can drift on.
    enum Signature {
        static let localHeader: UInt32 = 0x0403_4B50
        static let centralDirectory: UInt32 = 0x0201_4B50
        static let endOfCentralDirectory: UInt32 = 0x0605_4B50
    }

    enum Method {
        static let stored: UInt16 = 0
        static let deflated: UInt16 = 8
    }

    /// The largest member this will inflate — 64 MB.
    ///
    /// A roster's sheet is tens of kilobytes and its shared strings less, so this is three orders
    /// of magnitude of headroom and still a ceiling. Without one the destination buffer is sized
    /// by a number the file supplies, and a few hundred bytes of deflate can honestly claim to
    /// expand to gigabytes; the app would be killed for memory while opening a spreadsheet.
    static let sizeLimit = 64 * 1024 * 1024

    /// `PK\u{03}\u{04}` — the first four bytes of every non-empty ZIP, and so of every `.xlsx`.
    static let magic: [UInt8] = [0x50, 0x4B, 0x03, 0x04]

    // MARK: State

    private let bytes: [UInt8]
    /// Name to index entry. A dictionary because every lookup this type gets is by name —
    /// `xl/workbook.xml`, `xl/sharedStrings.xml`, whichever sheet the rels point at — and an
    /// `.xlsx` has a dozen members at most, so ordering buys nothing.
    private let entries: [String: Entry]

    private struct Entry {
        var method: UInt16
        var isEncrypted: Bool
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    // MARK: Opening

    init(_ data: Data) throws {
        // The one copy this type makes, and the reason it makes it is in the header: `Data`'s
        // indices are not guaranteed to start at zero and every offset in a ZIP is measured from
        // the start of the file. Storing it below is copy-on-write, not a second copy.
        let bytes = [UInt8](data)
        self.bytes = bytes

        let directoryStart = try Self.centralDirectoryOffset(in: bytes)
        var cursor = directoryStart
        var found: [String: Entry] = [:]

        // Walked to the end of the directory rather than for a counted number of entries: the
        // count in the end record is 16 bits and saturates on a ZIP64 archive, and the signature
        // is what actually says whether there is another entry.
        while cursor + 46 <= bytes.count, Self.u32(bytes, cursor) == Signature.centralDirectory {
            let flags = try Self.require(Self.u16(bytes, cursor + 8))
            let method = try Self.require(Self.u16(bytes, cursor + 10))
            let compressed = try Self.require(Self.u32(bytes, cursor + 20))
            let uncompressed = try Self.require(Self.u32(bytes, cursor + 24))
            let nameLength = Int(try Self.require(Self.u16(bytes, cursor + 28)))
            let extraLength = Int(try Self.require(Self.u16(bytes, cursor + 30)))
            let commentLength = Int(try Self.require(Self.u16(bytes, cursor + 32)))
            let localOffset = try Self.require(Self.u32(bytes, cursor + 42))

            if compressed == .max || uncompressed == .max || localOffset == .max {
                throw ReadError.zip64
            }

            let nameStart = cursor + 46
            guard nameStart + nameLength <= bytes.count else { throw ReadError.truncated }
            // UTF-8 whether or not bit 11 says so. Every name this reader asks for is ASCII, and
            // ASCII is a subset of both UTF-8 and the CP437 an old writer would have used, so the
            // one case the distinction would matter in cannot arise.
            let name = String(decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)

            found[name] = Entry(
                method: method,
                // Bit 0. Refused at read time rather than here, so an archive that merely
                // *contains* an encrypted member can still be opened for the ones that are not.
                isEncrypted: flags & 1 != 0,
                compressedSize: Int(compressed),
                uncompressedSize: Int(uncompressed),
                localHeaderOffset: Int(localOffset)
            )

            cursor = nameStart + nameLength + extraLength + commentLength
        }

        entries = found
    }

    // MARK: Reading a member

    /// Whether the archive holds a member under this exact name.
    func contains(_ name: String) -> Bool { entries[name] != nil }

    /// Every member name, for the callers that have to go looking — resolving a worksheet whose
    /// relationship target is missing, mostly.
    var names: [String] { Array(entries.keys) }

    /// The member's bytes, inflated. `nil` when the archive has no such member, which is a
    /// question rather than a failure: `xl/sharedStrings.xml` is genuinely absent from a workbook
    /// whose cells are all inline or numeric.
    func data(for name: String) throws -> Data? {
        guard let entry = entries[name] else { return nil }
        guard !entry.isEncrypted else { throw ReadError.encrypted }
        guard entry.uncompressedSize <= Self.sizeLimit else { throw ReadError.entryTooLarge(name) }

        // The payload's start is read off the **local** header, not the central directory: the
        // two are allowed to carry different extra fields, and it is the local one that sits
        // between the header and the bytes.
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, Self.u32(bytes, header) == Signature.localHeader else {
            throw ReadError.truncated
        }
        let nameLength = Int(try Self.require(Self.u16(bytes, header + 26)))
        let extraLength = Int(try Self.require(Self.u16(bytes, header + 28)))

        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard end <= bytes.count else { throw ReadError.truncated }
        let payload = bytes[start..<end]

        switch entry.method {
        case Method.stored:
            return Data(payload)
        case Method.deflated:
            guard let inflated = Self.inflate(payload, expecting: entry.uncompressedSize) else {
                throw ReadError.corruptEntry(name)
            }
            return Data(inflated)
        default:
            throw ReadError.unsupportedCompression(entry.method)
        }
    }

    // MARK: Inflating

    /// Raw DEFLATE, through `Compression`.
    ///
    /// `COMPRESSION_ZLIB` is Apple's name for RFC 1951 — the *raw* deflate stream, with none of
    /// zlib's own two-byte header or trailing Adler-32. That is exactly what a ZIP member holds,
    /// so the bytes go straight in. (The name is the trap: `COMPRESSION_ZLIB` sounds like it
    /// wants an RFC 1950 wrapper and does not.)
    ///
    /// One-shot rather than the streaming API, because the central directory already told us how
    /// large the result is. The destination is allocated at exactly that size and a return of
    /// anything else is treated as a failure — which also catches the ambiguous case where a
    /// truncated stream stops early and reports what it managed.
    private static func inflate(_ source: ArraySlice<UInt8>, expecting size: Int) -> [UInt8]? {
        // A zero-length member is legal and inflates to nothing. `withUnsafeBufferPointer` may
        // hand back a nil base address for an empty buffer, so neither side reaches the call.
        guard size > 0 else { return [] }
        guard !source.isEmpty else { return nil }

        var destination = [UInt8](repeating: 0, count: size)
        let written = destination.withUnsafeMutableBufferPointer { out in
            source.withUnsafeBufferPointer { input in
                compression_decode_buffer(
                    out.baseAddress!, size,
                    input.baseAddress!, input.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        return written == size ? destination : nil
    }

    // MARK: Finding the index

    /// Where the central directory starts, read out of the end-of-central-directory record.
    ///
    /// The record is 22 bytes plus a comment of up to 65535, and nothing says where it begins —
    /// so it is found by scanning backwards for its signature, which is what every ZIP reader
    /// does. Backwards rather than forwards so that a comment which happens to contain the
    /// signature loses to the real record.
    private static func centralDirectoryOffset(in bytes: [UInt8]) throws -> Int {
        let minimumRecord = 22
        guard bytes.count >= minimumRecord else { throw ReadError.notAZIP }

        let last = bytes.count - minimumRecord
        let first = max(0, bytes.count - minimumRecord - 0xFFFF)

        for candidate in stride(from: last, through: first, by: -1)
        where u32(bytes, candidate) == Signature.endOfCentralDirectory {
            let entryCount = try require(u16(bytes, candidate + 10))
            let offset = try require(u32(bytes, candidate + 16))
            if entryCount == .max || offset == .max { throw ReadError.zip64 }
            guard Int(offset) <= bytes.count else { throw ReadError.truncated }
            return Int(offset)
        }

        throw ReadError.notAZIP
    }

    // MARK: Little-endian reads

    /// Nil when the field runs off the end, which every caller turns into `.truncated`. Written
    /// as optionals rather than as throwing reads so the bounds check and the load are one
    /// expression at each of the sixteen call sites.
    private static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= bytes.count else { return nil }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw ReadError.truncated }
        return value
    }
}
