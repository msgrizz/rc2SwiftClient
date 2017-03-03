//
//  ConsoleOutputController.swift
//
//  Copyright © 2016 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa
import Networking

enum SessionStateKey: String {
	case History = "history"
	case Results = "results"
}

///ViewController whose view contains the text view showing the results, and the text field for entering short queries
class ConsoleOutputController: AbstractSessionViewController, OutputController, NSTextViewDelegate, NSTextFieldDelegate
{
	//MARK: properties
	@IBOutlet var resultsView: ResultsView?
	@IBOutlet var consoleTextField: ConsoleTextField?
	@IBOutlet var historyButton: NSSegmentedControl?
	var outputFont: NSFont = NSFont(name: "Menlo", size: 14)!
	let cmdHistory: CommandHistory
	dynamic var consoleInputText = "" { didSet { canExecute = consoleInputText.characters.count > 0 } }
	dynamic var canExecute = false
	var viewFileOrImage: ((_ fileWrapper: FileWrapper) -> ())?
	var currentFontDescriptor: NSFontDescriptor = NSFont.userFixedPitchFont(ofSize: 14.0)!.fontDescriptor {
		didSet {
			let font = NSFont(descriptor: currentFontDescriptor, size: currentFontDescriptor.pointSize)
			resultsView?.font = font
		}
	}
	
	required init?(coder: NSCoder) {
		cmdHistory = CommandHistory(target:nil, selector:#selector(ConsoleOutputController.displayHistoryItem(_:)))
		super.init(coder: coder)
	}
	
	//MARK: overrides
	override func viewDidLoad() {
		super.viewDidLoad()
		cmdHistory.target = self
		consoleTextField?.adjustContextualMenu = { (editor:NSText, theMenu:NSMenu) in
			return theMenu
		}
		resultsView?.textContainerInset = NSMakeSize(4, 4)
		//try switching to Menlo instead of default monospaced font
		let fdesc = NSFontDescriptor(name: "Menlo-Regular", size: 14.0)
		if let _ =  NSFont(descriptor: fdesc, size: fdesc.pointSize)
		{
			currentFontDescriptor = fdesc
		}
	}
	
	//MARK: actions
	@IBAction func executeQuery(_ sender:AnyObject?) {
		guard consoleInputText.characters.count > 0 else { return }
		session.executeScript(consoleInputText)
		cmdHistory.addToCommandHistory(consoleInputText)
		consoleTextField?.stringValue = ""
	}
	
	//MARK: SessionOutputHandler
	func append(responseString: ResponseString) {
		let mutStr = responseString.string.mutableCopy() as! NSMutableAttributedString
		mutStr.addAttributes([NSFontAttributeName:outputFont], range: NSMakeRange(0, mutStr.length))
		resultsView!.textStorage?.append(mutStr)
		resultsView!.scrollToEndOfDocument(nil)
	}
	
	func saveSessionState() -> AnyObject {
		var dict = [String:AnyObject]()
		dict[SessionStateKey.History.rawValue] = cmdHistory.commands as AnyObject?
		let rtfd = resultsView?.textStorage?.rtfd(from: NSMakeRange(0, (resultsView?.textStorage?.length)!), documentAttributes: [NSDocumentTypeDocumentAttribute:NSRTFDTextDocumentType])
		dict[SessionStateKey.Results.rawValue] = rtfd as AnyObject?
		dict["font"] = NSKeyedArchiver.archivedData(withRootObject: currentFontDescriptor) as AnyObject?
		return dict as AnyObject
	}

	func restoreSessionState(_ state:[String:AnyObject]) {
		if state[SessionStateKey.History.rawValue] is NSArray {
			cmdHistory.commands = state[SessionStateKey.History.rawValue] as! [String]
		}
		if state[SessionStateKey.Results.rawValue] is NSData {
			let data = state[SessionStateKey.Results.rawValue] as! Data
			let ts = resultsView!.textStorage!
			//for some reason, NSLayoutManager is initially making the line with an attachment 32 tall, even though image is 48. On window resize, it corrects itself. so we are going to keep an array of attachment indexes so we can fix this later
			var fileIndexes:[Int] = []
			resultsView!.replaceCharacters(in: NSMakeRange(0, ts.length), withRTFD:data)
			resultsView!.textStorage?.enumerateAttribute(NSAttachmentAttributeName, in: NSMakeRange(0, ts.length), options: [], using:
			{ (value, range, stop) -> Void in
				guard let attach = value as? NSTextAttachment else { return }
				let fw = attach.fileWrapper
				let fname = (fw?.filename!)!
				if fname.hasPrefix("img") {
					let cell = NSTextAttachmentCell(imageCell: NSImage(named: "graph"))
					cell.image?.size = ConsoleAttachmentImageSize
					ts.removeAttribute(NSAttachmentAttributeName, range: range)
					attach.attachmentCell = cell
					ts.addAttribute(NSAttachmentAttributeName, value: attach, range: range)
				} else {
					attach.attachmentCell = self.attachmentCellForAttachment(attach)
					fileIndexes.append(range.location)
				}
			})
			//now go through all lines with an attachment and insert a space, and then delete it. that forces a layout that uses the correct line height
			fileIndexes.forEach() {
				ts.insert(NSAttributedString(string: " "), at: $0)
				ts.deleteCharacters(in: NSMakeRange($0, 1))
			}
			if let fontData = state["font"] as? Data, let fontDesc = NSKeyedUnarchiver.unarchiveObject(with: fontData) {
				currentFontDescriptor = fontDesc as! NSFontDescriptor
			}
			//scroll to bottom
			resultsView?.moveToEndOfDocument(self)
		}
	}
	
	func attachmentCellForAttachment(_ attachment: NSTextAttachment) -> NSTextAttachmentCell? {
		guard let attach = try? MacConsoleAttachment.from(data: attachment.fileWrapper!.regularFileContents!) else { return nil }
		assert(attach.type == .file)
		let fileType = FileType.fileType(withExtension: attach.fileExtension!)
		let img = fileType?.image()
		img?.size = ConsoleAttachmentImageSize
		return NSTextAttachmentCell(imageCell: img)
	}
	
	//MARK: command history
	@IBAction func historyClicked(_ sender:AnyObject?) {
		cmdHistory.adjustCommandHistoryMenu()
		let hframe = historyButton?.superview?.convert((historyButton?.frame)!, to: nil)
		let rect = view.window?.convertToScreen(hframe!)
		cmdHistory.historyMenu.popUp(positioning: nil, at: (rect?.origin)!, in: nil)
	}

	@IBAction func displayHistoryItem(_ sender:AnyObject?) {
		let mi = sender as! NSMenuItem
		consoleInputText = mi.representedObject as! String
		canExecute = consoleInputText.characters.count > 0
		//the following shouldn't be necessary because they are bound. But sometimes the textfield value does not update
		consoleTextField?.stringValue = consoleInputText
		view.window?.makeFirstResponder(consoleTextField)
	}
	
	@IBAction func clearConsole(_ sender:AnyObject?) {
		resultsView?.textStorage?.deleteCharacters(in: NSMakeRange(0, (resultsView?.textStorage?.length)!))
	}
	
	//MARK: textfield delegate
	func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
		if commandSelector == #selector(NSResponder.insertNewline(_:)) {
			executeQuery(control)
			return true
		}
		return false
	}
	
	//MARK: textview delegate
	func textView(_ textView: NSTextView, clickedOn cell: NSTextAttachmentCellProtocol, in cellFrame: NSRect, at charIndex: Int)
	{
		let attach = cell.attachment
		guard let fw = attach?.fileWrapper else { return }
		viewFileOrImage?(fw)
	}
}

extension ConsoleOutputController: Searchable {
	func performFind(action: NSTextFinderAction) {
		let menuItem = NSMenuItem(title: "foo", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "")
		menuItem.tag = action.rawValue
		resultsView?.performFindPanelAction(menuItem)
	}
}

//MARK: UsesAdjustableFont
extension ConsoleOutputController: UsesAdjustableFont {
	
	func fontsEnabled() -> Bool {
		return true
	}
	
	func fontChanged(_ menuItem:NSMenuItem) {
		guard let newNameDesc = menuItem.representedObject as? NSFontDescriptor else { return }
		let newDesc = newNameDesc.withSize(currentFontDescriptor.pointSize)
		currentFontDescriptor = newDesc
		resultsView?.font = NSFont(descriptor: newDesc, size: newDesc.pointSize)
	}
}
