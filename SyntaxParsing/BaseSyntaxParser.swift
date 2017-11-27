//
//  SyntaxParser
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
#if os(OSX)
	import AppKit
#endif
import os
import ClientCore
import Model
import ReactiveSwift

/// parses the contents of an NSTextStorage into an array of chunks that can be syntax colored
public class BaseSyntaxParser: NSObject, SyntaxParser {
	///returns the approprate syntax parser to use for fileType
	public class func parserWithTextStorage(_ storage: NSTextStorage, fileType: FileType, helpCallback: @escaping HighlighterHasHelpCallback) -> BaseSyntaxParser?
	{
		var parser: BaseSyntaxParser?
		var highlighter: CodeHighlighter?
		if fileType.fileExtension == "Rnw" {
			parser = RnwSyntaxParser(storage: storage, fileType: fileType, helpCallback: helpCallback)
		} else if fileType.fileExtension == "Rmd" {
			parser = RmdSyntaxParser(storage: storage, fileType: fileType, helpCallback: helpCallback)
		} else if fileType.fileExtension == "R" {
			parser = RSyntaxParser(storage: storage, fileType: fileType, helpCallback: helpCallback)
			highlighter = RCodeHighlighter(helpCallback: helpCallback)
		}
		parser?.codeHighlighter = highlighter
		return parser
	}
	
	public let textStorage: NSTextStorage
	public let fileType: FileType
	public let theme = Property(ThemeManager.shared.activeSyntaxTheme)
	public internal(set) var chunks: [DocumentChunk] = []
	fileprivate var lastSource: String = ""
	var colorBackgrounds = false
	
	public var executableChunks: [DocumentChunk] { return chunks.filter({ $0.type == .executable }) }
	
	internal var docHighlighter: CodeHighlighter?
	internal var codeHighlighter: CodeHighlighter?
	
	/// - parameter storage: A text storage whose changes are tracked to keep chunks up to date
	/// - parameter fileType: used to determine the proper highlighter(s) to use
	init(storage: NSTextStorage, fileType: FileType, helpCallback: @escaping HighlighterHasHelpCallback)
	{
		self.textStorage = storage
		self.fileType = fileType
		super.init()
		codeHighlighter?.helpCallback = helpCallback
	}
	
	///returns the index of the chunk in the specified range
	public func indexOfChunk(range inRange: NSRange) -> Int {
		guard chunks.count > 0,
			let selRange = chunksForRange(inRange).first,
			let chunkIndex = chunks.index(of: selRange)
			else { return 0 }
		return chunkIndex
	}
	
	public func chunksForRange(_ range: NSRange) -> [DocumentChunk] {
		//if full range of textstorage, just return all chunks
		if NSEqualRanges(range, NSRange(location: 0, length: textStorage.length)) {
			return chunks
		}
		guard chunks.count > 0 else { return [] }
		if range.length == 0 {
			guard range.location > 0 else { return [chunks[0]] }
			for aChunk in chunks {
				if NSLocationInRange(range.location, aChunk.parsedRange) {
					return [aChunk]
				}
			}
		}
		os_log("looking for %{public}@", log: .syntax, type: .debug, NSStringFromRange(range))
		var outArray: [DocumentChunk] = []
		for aChunk in chunks {
			if NSIntersectionRange(aChunk.parsedRange, range).length > 0
				//				|| NSLocationInRange(range.location-1, aChunk.parsedRange)
			{
				outArray.append(aChunk)
			}
		}
		return outArray
	}
	
	///returns true if the chunks changed
	@discardableResult
	public func parse() -> Bool {
		if textStorage.length == 0 || textStorage.string != lastSource {
			let oldChunks = chunks
			parseRange(NSRange(location: 0, length: textStorage.length))
			lastSource = textStorage.string
			if oldChunks == chunks {
				return false
			}
		}
		return true
	}
	
	internal func parseRange(_ range: NSRange) {
		preconditionFailure("subclass must implement")
	}
	
	///should be called when the textstorage contents have changed, ideally by the NSTextStorageDelegate call textStorage:didProcessEditing:range:changeInLength:
	func adjustParseRanges(_ fullRangeLength: Int) {
		guard chunks.count > 0 else { return }
		for (index, chunk) in chunks.enumerated() {
			guard index + 1 < chunks.count - 1 else { break }
			let nextChunk = chunks[index + 1]
			var rng = chunk.parsedRange
			rng.length = nextChunk.parsedRange.location - chunk.parsedRange.location
			chunk.parsedRange = rng
		}
		//adjust last one
		var finalRange = chunks.last!.parsedRange
		finalRange.length = fullRangeLength - finalRange.location
		chunks.last!.parsedRange = finalRange
	}
	
	public func colorChunks(_ chunksToColor: [DocumentChunk]) {
		for chunk in chunksToColor {
			if chunk.type == .executable {
				if colorBackgrounds {
					let bgcolor = theme.value.color(for: .codeBackground)
					textStorage.addAttribute(.backgroundColor, value: bgcolor, range: chunk.parsedRange)
				}
				codeHighlighter?.highlightText(textStorage, range: chunk.parsedRange)
			} else if chunk.type == .documentation {
				docHighlighter?.highlightText(textStorage, range: chunk.parsedRange)
			} else if chunk.type == .equation && colorBackgrounds {
				let bgcolor = theme.value.color(for: .equationBackground)
				textStorage.addAttribute(.backgroundColor, value: bgcolor, range: chunk.parsedRange)
			}
		}
	}
}

class RSyntaxParser: BaseSyntaxParser {
	internal override func parseRange(_ range: NSRange) {
		chunks.removeAll()
		let chunk = DocumentChunk(chunkType: .executable, chunkNumber: 1)
		chunk.parsedRange = NSRange(location: 0, length: textStorage.string.count)
		chunks.append(chunk)
	}
}
