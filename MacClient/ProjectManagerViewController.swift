//
//  ProjectManagerViewController.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa
import Networking

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


struct ProjectAndWorkspace {
	let project:String
	let workspace:String
}

class ProjectManagerViewController: NSViewController, EmbeddedDialogController {
	@IBOutlet var projectOutline:NSOutlineView?
	@IBOutlet var addRemoveButtons:NSSegmentedControl?
	
	dynamic var canContinue:Bool = false
	
	var host:ServerHost?
	var connectInfo: ConnectionInfo?

	override open func viewDidAppear() {
		super.viewDidAppear()
		projectOutline?.reloadData()
		projectOutline?.expandItem(nil, expandChildren: true)
	}
	
	func continueAction(_ callback: @escaping (_ value:Any?, _ error:NSError?) -> Void) {
		if let wspace = projectOutline?.item(atRow: projectOutline!.selectedRow) as? Workspace,
			let project = connectInfo!.project(withId: wspace.projectId)
		{
			let pw = ProjectAndWorkspace(project: project.name, workspace: wspace.name)
			callback(pw, nil)
		} else {
			callback(nil, NSError.error(withCode: .impossible, description: "should not be able to continue w/o a workspace selected"))
		}
	}
	
	@IBAction func addRemoveAction(_ sender:AnyObject?) {
		
	}
}

extension ProjectManagerViewController: NSOutlineViewDataSource {
	
	public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if nil == item {
			return connectInfo!.projects.count
		} else if let proj = item as? Project {
			return proj.workspaces.count
		}
		return 0
	}
	
	public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is Project
	}
	
	public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if let proj = item as? Project {
			return proj.workspaces[index]
		}
		return connectInfo!.projects[index]
	}
}

extension ProjectManagerViewController: NSOutlineViewDelegate {
	public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView?
	{
		var val = "";
		if let proj = item as? Project {
			val = proj.name
		} else if let wspace = item as? Workspace {
			val = wspace.name
		}
		let view = outlineView.make(withIdentifier: "string", owner: nil) as? NSTableCellView
		view?.textField?.stringValue = val
		return view
	}
	
	public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		return item is Workspace
	}
	
	public func outlineViewSelectionDidChange(_ notification: Notification) {
		canContinue = projectOutline?.selectedRow >= 0
	}
}
