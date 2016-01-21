//
//  MainWindowController.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa

class MainWindowController: NSWindowController, ToolbarDelegatingOwner, NSToolbarDelegate {
	@IBOutlet var rootTabController: NSTabViewController?
	private var toolbarSetupScheduled = false
	
	override func windowDidLoad() {
		super.windowDidLoad()
		rootTabController = firstRecursiveDescendent(contentViewController!,
			children: { $0.childViewControllers },
			filter: { $0 is NSTabViewController })  as? NSTabViewController
		showWorkspaceSelectTab()
		let workspacesVC = firstRecursiveDescendent(rootTabController!, children: {$0.childViewControllers}, filter: {$0 is WorkspacesViewController}) as! WorkspacesViewController
		workspacesVC.actionCallback = { (controller:WorkspacesViewController, workspaceName:String) in
			self.showSessionTab()
			self.window!.title = String.localizedStringWithFormat(NSLocalizedString("WindowTitleFormat", comment: ""), workspaceName)
		}
	}
	
	func showWorkspaceSelectTab() {
		rootTabController?.selectedTabViewItemIndex = (rootTabController?.tabView.indexOfTabViewItemWithIdentifier("workspaceSelect"))!
	}
	
	func showSessionTab() {
		rootTabController?.selectedTabViewItemIndex = (rootTabController?.tabView.indexOfTabViewItemWithIdentifier("session"))!
	}
	
	func toolbarWillAddItem(notification: NSNotification) {
		//schedule assigning handlers after toolbar items are loaded
		if !toolbarSetupScheduled {
			dispatch_async(dispatch_get_main_queue()) { () -> Void in
				self.assignHandlers(self.contentViewController!, items: (self.window?.toolbar?.items)!)
			}
			toolbarSetupScheduled = true
		}
	}
}