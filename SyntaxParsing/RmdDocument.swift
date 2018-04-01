//
//  RmdDocument.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Model
import MJLLogger
import ReactiveSwift

public typealias ParserErrorHandler = (ParserError) -> Void

public class RmdDocument {
	/// the chunks comprising this document
	public var chunks: [RmdChunk] { return internalChunks }
	/// front matter
	public let frontMatter = MutableProperty("")
	
	private var internalChunks: [InternalRmdChunk] = []
	private var textStorage = NSTextStorage()
	private var parser: BaseSyntaxParser
	
	/// create a structure document
	///
	/// - Parameters:
	///   - contents: initial contents of the document
	///   - helpCallback: callback that returns true if a term should be highlighted as a help term
	public init(contents: String, helpCallback: @escaping  HasHelpCallback) throws {
		textStorage.append(NSAttributedString(string: contents))
		parser = BaseSyntaxParser.parserWithTextStorage(textStorage, fileType: FileType.fileType(withExtension: "Rmd")!, helpCallback: helpCallback)!
		parser.parse()
		frontMatter.value = parser.frontMatter
		var lastTextChunk: MarkdownChunk?
		var lastWasInline: Bool = false
		try parser.chunks.forEach { parserChunk in
			switch parserChunk.chunkType {
			case .docs:
				let chunkContents = parser.textStorage.attributedSubstring(from: parserChunk.innerRange)
				let whitespaceOnly = chunkContents.string.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) == nil
				if lastWasInline || whitespaceOnly {
					// need to append this chunk's content to lastTextChunk
					lastTextChunk?.textStorage.append(chunkContents)
					lastWasInline = false
					return
				}
				let tchunk = MarkdownChunk(parser: parser, contents: parser.textStorage.string, range: parserChunk.innerRange)
				append(chunk: tchunk)
				lastTextChunk = tchunk
				lastWasInline = false
			case .code:
				let cchunk = InternalCodeChunk(parser: parser, contents: parser.textStorage.string, range: parserChunk.innerRange, options: parserChunk.rOps)
				if parserChunk.isInline, let lastChunk = lastTextChunk {
					let achunk = InternalInlineCodeChunk(parser: parser, contents: parser.textStorage.string, range: parserChunk.innerRange)
					attach(chunk: achunk, to: lastChunk.textStorage)
					lastWasInline = true
					return
				}
				append(chunk: cchunk)
				lastWasInline = parserChunk.isInline
				if !lastWasInline { lastTextChunk = nil }
			case .equation:
				switch parserChunk.equationType {
				case .none: fatalError()
				case .inline:
					guard let lastChunk = lastTextChunk else { throw ParserError.inlineEquationNotInTextChunk }
					let dchunk = InternalInlineEquation(parser: parser, contents: parser.textStorage.string, range: parserChunk.innerRange)
					lastChunk.inlineElements.append(dchunk)
					attach(chunk: dchunk, to: lastChunk.textStorage)
					lastWasInline = true
				case .display:
					let dchunk = InternalEquationChunk(parser: parser, contents: parser.textStorage.string, range: parserChunk.parsedRange, innerRange: parserChunk.innerRange)
					append(chunk: dchunk)
					lastTextChunk = nil
					lastWasInline = false
				case .mathML:
					print("MathML not supported yet")
				}
			}
		}
	}
	
	private func attach(chunk: InlineChunk, to storage: NSTextStorage) {
		let attach = InlineAttachment()
		attach.chunk = chunk
		let image = chunk is Equation ? #imageLiteral(resourceName: "inlineEquation") : #imageLiteral(resourceName: "inlineCode")
		let acell = InlineAttachmentCell(imageCell: image)
		attach.bounds = CGRect(origin: CGPoint(x: 0, y: -5), size: acell.image!.size)
		attach.attachmentCell = acell
		storage.append(NSAttributedString(attachment: attach))
	}
	
	private func append(chunk: InternalRmdChunk) {
		internalChunks.append(chunk)
	}
	
	public func moveChunk(from startIndex: Int, to endIndex: Int) {
		assert(startIndex >= 0)
		assert(endIndex >= 0) //don't check high constraint because anything larger than count will move to end
		guard startIndex != endIndex else { return }
		if endIndex >= internalChunks.count {
			let elem = internalChunks[startIndex]
			internalChunks.remove(at: startIndex)
			internalChunks.append(elem)
			return
		} else if endIndex > startIndex {
			let elem = internalChunks.remove(at: startIndex)
			internalChunks.insert(elem, at: endIndex - 1)
		} else {
			let elem = internalChunks.remove(at: startIndex)
			internalChunks.insert(elem, at: endIndex)
		}
	}
	
	public func insertTextChunk(initalContents: String, at index: Int) {
		let chunk = MarkdownChunk(parser: parser, contents: initalContents, range: initalContents.fullNSRange)
		internalChunks.insert(chunk, at: index)
	}

	public func insertCodeChunk(initalContents: String, at index: Int) {
		let chunk = InternalCodeChunk(parser: parser, contents: initalContents, range: initalContents.fullNSRange, options: nil)
		internalChunks.insert(chunk, at: index)
	}

	public func insertEquationChunk(initalContents: String, at index: Int) {
		let chunk = InternalEquationChunk(parser: parser, contents: initalContents, range: initalContents.fullNSRange, innerRange: initalContents.fullNSRange)
		internalChunks.insert(chunk, at: index)
	}
}

// MARK: - protocols

public protocol Equation: class {}

public protocol Code: class {}

public protocol RmdChunk: class {
	var textStorage: NSTextStorage { get }
	var chunkType: ChunkType { get }
	var rawText: String { get }
}

public protocol InlineChunk: RmdChunk {}

public protocol TextChunk: RmdChunk {
	var inlineElements: [InlineChunk] { get }
}

// MARK: - attachments
class InlineAttachment: NSTextAttachment {
	weak var chunk: InlineChunk?
	
//	override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> NSRect {
//		let font = textContainer?.textView?.font ?? NSFont.userFixedPitchFont(ofSize: 14.0)
//		let height = lineFrag.size.height
//		var scale: CGFloat = 1.0
//		let imageSize = image!.size
//		if (height < imageSize.height) {
//			scale = CGFloat(height / imageSize.height)
//		}
//		print("returning size")
//		return CGRect(x: 0, y: 15, width: imageSize.width * scale, height: imageSize.height * scale)
////		return CGRect(x: 0, y: (font!.capHeight - imageSize.height).rounded() / 2, width: imageSize.width * scale, height: imageSize.height * scale)
//	}
}

class InlineAttachmentCell: NSTextAttachmentCell {
	override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect, glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
		var rect = super.cellFrame(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
		// why does magic number work for all font sizes?
		rect.origin.y = -5
		return rect
	}
}

// MARK: - chunks

class InternalRmdChunk: NSObject, RmdChunk, ChunkProtocol, NSTextStorageDelegate {
	weak var parser: BaseSyntaxParser?
//	var parserChunk: DocumentChunk
	var textStorage: NSTextStorage
	let chunkType: ChunkType
	let docType: DocType
	let equationType: EquationType
	
	var rawText: String { return textStorage.string }
	
	init(parser: BaseSyntaxParser, chunk: DocumentChunk) {
		self.parser = parser
		self.chunkType = chunk.chunkType
		self.docType = chunk.docType
		self.equationType = chunk.equationType
//		self.parserChunk = chunk
		textStorage = NSTextStorage()
		super.init()
		textStorage.delegate = self
	}

	// called when text editing has ended
	public func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int)
	{
		//we don't care if attributes changed
		guard editedMask.contains(.editedCharacters) else { return }
		Log.debug("did edit: \(textStorage.string.substring(from: editedRange) ?? "")", .core)
		parser?.highLighter?.highlightText(textStorage, range: textStorage.string.fullNSRange, chunk: self)
//		parser?.colorChunks([parserChunk])
	}
}

// MARK: -
class MarkdownChunk: InternalRmdChunk, TextChunk {
	var inlineElements: [InlineChunk]
	
	init(parser: BaseSyntaxParser, contents: String, range: NSRange) {
		// use a fake chunk to create from contents
		let pchunk = DocumentChunk(chunkType: .docs, docType: .rmd, equationType: .none,
								   range: range, innerRange: range, chunkNumber: 1)
		inlineElements = []
		super.init(parser: parser, chunk: pchunk)
		textStorage.append(NSAttributedString(string: contents.substring(from: range)!))
	}
	
//	override var attributedContents: NSAttributedString {
//		let out = NSMutableAttributedString(attributedString: storage)
//		storage.enumerateAttribute(.attachment, in: out.string.fullNSRange, options: [.reverse])
//		{ (value, attrRange, stopPtr) in
//			guard let ival = value as? InlineAttachment,
//				let chunk = ival.chunk as? InternalRmdChunk,
//				let cell = ival.attachmentCell as? NSCell
//			else { return }
//			out.replaceCharacters(in: attrRange, with: chunk.storage)
//		}
//		return out
//	}
}

// MARK: -
class InternalCodeChunk: InternalRmdChunk, Code {
	var options: String
	init(parser: BaseSyntaxParser, contents: String, range: NSRange, options: String?) {
		self.options = options ?? ""
		let pchunk = DocumentChunk(chunkType: .code, docType: .rmd, equationType: .none,
								   range: range, innerRange: range, chunkNumber: 1)
		super.init(parser: parser, chunk: pchunk)
		textStorage.append(NSAttributedString(string: contents.substring(from: range)!))
	}
}

// MARK: -
class InternalEquationChunk: InternalRmdChunk, Equation {
	init(parser: BaseSyntaxParser, contents: String, range: NSRange, innerRange: NSRange) {
		let pchunk = DocumentChunk(chunkType: .equation, docType: .latex, equationType: .display,
								   range: range, innerRange: innerRange, chunkNumber: 1)
		super.init(parser: parser, chunk: pchunk)
		textStorage.append(NSAttributedString(string: contents.substring(from: range)!))
	}
}

// MARK:

class InternalInlineEquation: InternalRmdChunk, InlineChunk, Equation {
	init(parser: BaseSyntaxParser, contents: String, range: NSRange) {
		let pchunk = DocumentChunk(chunkType: .equation, docType: .latex, equationType: .inline,
								   range: range, innerRange: range, chunkNumber: 1)
		super.init(parser: parser, chunk: pchunk)
		textStorage.append(NSAttributedString(string: contents.substring(from: range)!))
	}
}

class InternalInlineCodeChunk: InternalRmdChunk, InlineChunk, Code {
	init(parser: BaseSyntaxParser, contents: String, range: NSRange) {
		let pchunk = DocumentChunk(chunkType: .code, docType: .rmd, equationType: .none,
								   range: range, innerRange: range, chunkNumber: 1)
		super.init(parser: parser, chunk: pchunk)
		textStorage.append(NSAttributedString(string: contents.substring(from: range)!))
	}
}

