//
//  MainWindowController.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa
import  ClientCore
import Networking
import os

class MainWindowController: NSWindowController, NSWindowDelegate, ToolbarDelegatingOwner, NSToolbarDelegate {
	///Object that lets us monitor the status of the application. Nededed to pass on to the statusView once setup is finished
	weak var appStatus: MacAppStatus?
	
	//TODO: this needs to eventually include  host and project name
	weak var session: Session? { didSet { window?.title = session?.workspace.name ?? "remote connection" } }
	
	///Custom view that shows the status of the application: progress, message, cancel button
	var statusView: AppStatusView?
	
	/// Need to schedule setting up toolbar handlers, but don't want to do it more than once
	fileprivate var toolbarSetupScheduled = false
	
	class func createFromNib() -> Self {
		let winc = self.init(windowNibName: NSNib.Name(rawValue: "MainWindow"))
		return winc
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
//		window!.titleVisibility = .hidden
	}
	
	func setupChildren() {
		statusView?.appStatus = appStatus
		let rootVC = contentViewController as! RootViewController // swiftlint:disable:this force_cast
		rootVC.sessionClosedHandler = { [weak self] in
			DispatchQueue.main.async {
				self?.window?.close()
			}
		}
		let viewControllers = recursiveFlatMap(rootVC, children: { $0.childViewControllers }, transform: { $0 as? AbstractSessionViewController })
		for aController in viewControllers {
			aController.sessionOptional = session
		}
	}

	func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
		guard let session = session else { return }
		guard let coder = state as? NSKeyedArchiver else { fatalError("restoring state from non keyed encoder") }
		let bmark = Bookmark(connectionInfo: session.conInfo, workspace: session.workspace.model, lastUsed: NSDate.timeIntervalSinceReferenceDate)
		do {
			try coder.encodeEncodable(try session.conInfo.encode(bmark), forKey: "bookmark")
		} catch {
			os_log("error encoding bookmark in window: %{public}@", log: .app, error as NSError)
		}
	}
	
	//When the first toolbar item is loaded, queue a closure to call assignHandlers from the ToolbarDelegatingOwner protocol(default implementation) that assigns each toolbar item to the appropriate ToolbarItemHandler (normally a view controller)
	func toolbarWillAddItem(_ notification: Notification) {
		//schedule assigning handlers after toolbar items are loaded
		if !toolbarSetupScheduled {
			DispatchQueue.main.async {
				self.assignHandlers(self.contentViewController!, items: (self.window?.toolbar?.items)!)
			}
			toolbarSetupScheduled = true
		}
		let item: NSToolbarItem = ((notification as NSNotification).userInfo!["item"] as? NSToolbarItem)!
		if item.itemIdentifier.rawValue == "status",
			let sview = item.view as? AppStatusView
		{
			statusView = sview
		}
	}
}
