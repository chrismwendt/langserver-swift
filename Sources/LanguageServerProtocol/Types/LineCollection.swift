//
//  LineCollection.swift
//  langserver-swift
//
//  Created by Ryan Lovelett on 11/22/16.
//
//

import Foundation
import ICU

extension Character {
    var isBreak: Bool {
        return self == "\u{0D}\u{0A}" || self == "\u{0A}"
    }
}

private struct LineIterator: IteratorProtocol {
    
    var cursor: LineBreakCursor
    
    var last: String.Index
    
    init(cursor: LineBreakCursor) {
        self.cursor = cursor
        last = self.cursor.first()
    }
    
    mutating func next() -> Range<String.Index>? {
        while let lineBreak = cursor.next() {
            if .hard ~= cursor.ruleStatus {
                defer { last = lineBreak }
                return Range(uncheckedBounds: (lower: last, upper: lineBreak))
            } else {
                continue
            }
        }
        return nil
    }
    
}

struct LineCollection {

    let data: String

    let lines: [Range<String.Index>]

    init(for file: URL) throws {
        let str = try String(contentsOf: file, encoding: .utf8)
        self.init(for: str)
    }

    init(for string: String) {
        if !string[string.index(before: string.endIndex)].isBreak {
            data = (string + "\n")
        } else {
            data = string
        }
        let c = LineBreakCursor(text: data)
        lines = Array(AnySequence({ LineIterator(cursor: c) }))
    }

    func byteOffset(at: Position) throws -> Int {
        guard at.line < lines.count else { throw WorkspaceError.positionNotFound }
        let lineRange = lines[at.line]
        guard let index = data.index(lineRange.lowerBound, offsetBy: at.character, limitedBy: data.endIndex), index < lineRange.upperBound else {
            throw WorkspaceError.positionNotFound
        }
        let utf8Index = index.samePosition(in: data.utf8)!
        return data.utf8.distance(from: data.utf8.startIndex, to: utf8Index)
    }

    func position(for offset: Int) throws -> Position {
        guard offset >= 0 else {
            throw WorkspaceError.positionNotFound
        }
        let index = String.Index(encodedOffset: offset)
        guard let lineIndex = lines.index(where: { $0.contains(index) }) else { throw WorkspaceError.positionNotFound }
        let lineRange = lines[lineIndex]
        let x = data.distance(from: lineRange.lowerBound, to: index)
        let position = Position(line: lineIndex, character: x)
        return position
    }

    func selection(startAt offset: Int, length: Int) throws -> TextDocumentRange {
        let endOffset = Int(offset + length)
        let start = try position(for: offset)
        let end = try position(for: endOffset)
        return TextDocumentRange(start: start, end: end)
    }

}
