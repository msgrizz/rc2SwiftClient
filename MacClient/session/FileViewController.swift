//
//  FileViewController.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa

class FileRowData {
	var sectionName:String?
	var file:File?
	init(name:String?, file:File?) {
		self.sectionName = name
		self.file = file
	}
}

protocol FileViewControllerDelegate: class {
	func fileSelectionChanged(file:File?)
	func renameFile(file:File, to:String)
	func importFiles(files:[NSURL])
}

let FileDragTypes = [kUTTypeFileURL as String]

//TODO: make sure when delegate renames file our list gets updated

class FileViewController: AbstractSessionViewController, NSTableViewDataSource, NSTableViewDelegate, FileHandler, NSOpenSavePanelDelegate, NSMenuDelegate
{
	//MARK: properties
	let sectionNames:[String] = ["Source Files", "Images", "Other"]

	@IBOutlet var tableView: NSTableView!
	@IBOutlet var addRemoveButtons:NSSegmentedControl?
	var rowData:[FileRowData] = [FileRowData]()
	var delegate:FileViewControllerDelegate?
	var fileImporter:MacFileImportSetup?
	
	var selectedFile:File? {
		guard tableView.selectedRow >= 0 else { return nil }
		return rowData[tableView.selectedRow].file
	}

	//MARK: - lifecycle
	override func awakeFromNib() {
		super.awakeFromNib()

		if addRemoveButtons != nil {
			let menu = NSMenu(title: "new document format")
			for (index, aType) in FileType.creatableFileTypes.enumerate() {
				let mi = NSMenuItem(title: aType.details, action: "addDocumentOfType:", keyEquivalent: "")
				mi.representedObject = index
				menu.addItem(mi)
			}
			menu.autoenablesItems = false
			//NOTE: the action method of the menu item wasn't being called the first time. This works all times.
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "addFileMenuAction:", name: NSMenuDidSendActionNotification, object: menu)
			addRemoveButtons?.setMenu(menu, forSegment: 0)
			addRemoveButtons?.target = self
			addRemoveButtons?.action = "addButtonClicked:"
		}
		if tableView != nil {
			tableView.setDraggingSourceOperationMask(.Copy, forLocal: true)
			tableView.draggingDestinationFeedbackStyle = .None
			tableView.registerForDraggedTypes(FileDragTypes)
		}
	}
	
	override func sessionChanged() {
		loadData()
		tableView.reloadData()
	}
	
	override func appStatusChanged() {
		NSNotificationCenter.defaultCenter().addObserverForName(AppStatusChangedNotification, object: nil, queue: nil) { (note) -> Void in
			assert(self.appStatus != nil, "appStatus not set on FileViewController")
			if let tv = self.tableView, let apps = self.appStatus {
				if apps.busy {
					tv.unregisterDraggedTypes()
				} else {
					tv.registerForDraggedTypes(FileDragTypes)
				}
			}
		}
	}
	
	func loadData() {
		var sectionedFiles = [[File](), [File](), [File]()]
		for aFile in session.workspace.files {
			if aFile.fileType.isSourceFile {
				sectionedFiles[0].append(aFile)
			} else if aFile.fileType.isImage {
				sectionedFiles[1].append(aFile)
			} else {
				sectionedFiles[2].append(aFile)
			}
		}
		//sort each one
		for var fa in sectionedFiles {
			fa.sortInPlace({ $0.name > $1.name })
		}
		rowData.removeAll()
		for i in 0..<sectionNames.count {
			if sectionedFiles[i].count > 0 {
				rowData.append(FileRowData(name: sectionNames[i], file: nil))
				rowData.appendContentsOf(sectionedFiles[i].map({ return FileRowData(name:nil, file:$0)}))
			}
		}
	}
	
	override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
		switch(menuItem.action) {
			case "importFiles:":
				return true
			case "exportSelectedFile:":
				return selectedFile != nil
			case "exportAllFiles:":
				return true
			default:
				return super.validateMenuItem(menuItem)
		}
	}
	
	func menuNeedsUpdate(menu: NSMenu) {
		menu.itemArray.filter() { item in
			return item.action == "exportSelectedFile:"
		}.first?.enabled = selectedFile != nil
	}
	
	//MARK: - actions
	func addButtonClicked(sender:AnyObject?) {
		log.info("called for \(addRemoveButtons?.selectedSegment)")
	}
	
	func addFileMenuAction(note:NSNotification) {
		let menuItem = note.userInfo!["MenuItem"] as! NSMenuItem
		let index = menuItem.representedObject as! Int
		let fileType = FileType.creatableFileTypes[index]
		print("add file of type \(fileType.name)")
	}
	
	func removeFileMenuItem(sender:AnyObject?) {
		log.info("remove selcted file")
	}
	
	//MARK: - import/export
	@IBAction func importFiles(sender:AnyObject?) {
		if nil == fileImporter {
			fileImporter = MacFileImportSetup()
		}
		fileImporter!.performFileImport(view.window!, workspace: session.workspace) { files in
			//TODO: implement actual file import
		}
	}
	
	@IBAction func exportSelectedFile(sender:AnyObject?) {
		
	}
	
	@IBAction func exportAllFiles(sender:AnyObject?) {
		
	}

	//MARK: - FileHandler implementation
	func filesRefreshed() {
		loadData()
		tableView.reloadData()
	}
	
	//MARK: - TableView datasource/delegate implementation
	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return rowData.count
	}
	
	func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let data = rowData[row]
		if data.sectionName != nil {
			let tview = tableView.makeViewWithIdentifier("string", owner: nil) as! NSTableCellView
			tview.textField!.stringValue = data.sectionName!
			return tview
		} else {
			let fview = tableView.makeViewWithIdentifier("file", owner: nil) as! SessionCellView
			fview.file = data.file
			fview.editComplete = { self.delegate?.renameFile($0.file!, to: $0.nameField.stringValue) }
			return fview
		}
	}
	
	func tableView(tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return rowData[row].sectionName != nil
	}
	
	func tableViewSelectionDidChange(notification: NSNotification) {
		delegate?.fileSelectionChanged(selectedFile)
	}
	
	func tableView(tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation
	{
		return fileImporter!.validateTableViewDrop(info)
	}

	func tableView(tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool
	{
		fileImporter!.acceptTableViewDrop(info, workspace: session.workspace, window: view.window!) { (files) in
			//TODO: implement update of table view after drop import
		}
		return true
	}
}

public class SessionCellView : NSTableCellView, NSTextFieldDelegate {
	@IBOutlet var nameField: NSTextField!
	var file:File? {
		didSet { nameField?.stringValue = (file?.name)! }
	}

	var editComplete:((cell:SessionCellView) -> Void)?
	
	public override func controlTextDidEndEditing(obj: NSNotification) {
		nameField.editable = false
		editComplete?(cell: self)
		nameField.stringValue = (file?.name)!
	}
}

//least hackish way to get segment's menu to show immediately if set, otherwise perform control's action
class AddRemoveSegmentedCell : NSSegmentedCell {
	override var action: Selector {
		get {
			if self.menuForSegment(self.selectedSegment) != nil { return nil }
			return super.action
		}
		set { super.action = newValue }
	}
}

class FileTableView: NSTableView {
	override func menuForEvent(event: NSEvent) -> NSMenu? {
		let row = rowAtPoint(convertPoint(event.locationInWindow, fromView: nil))
		if row != -1 { //if right click is over a row, select that row
			selectRowIndexes(NSIndexSet(index: row), byExtendingSelection: false)
		}
		return super.menuForEvent(event)
	}
}

