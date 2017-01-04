//
//  SessionHandlerProtocols.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa
import Networking
import NotifyingCollection

///These protocols exist to decouple various view controllers

/// Abstracts the idea of processing variable messages
public protocol VariableHandler {
	///parameter variables: key is a string, value is an ObjcBox of a JSON value
	/// - parameter single: if this is an update for a single variable, or a delta
	/// - paramter variables: the variable objects from the server
	func handleVariableMessage(_ single:Bool, variables:[Variable])
	
	/// handle a delta change message
	/// - parameter assigned: variabless that were assigned (insert or update)
	/// - parameter: removed: variables that werer deleted
	func handleVariableDeltaMessage(_ assigned:[Variable], removed:[String])
}

protocol OutputHandler: class {
	var sessionController: SessionController? { get set }
	func append(responseString: ResponseString)
	func saveSessionState() -> AnyObject
	func restoreSessionState(_ state: [String: AnyObject])
	func prepareForSearch()
	func initialFirstResponder() -> NSResponder
	//can't use File as parameter class because it isn't available in ObjC. We let the bridge pass the object around using AnyObject and the destination will have to cast it to a File object.
	func showFile(_ file: AnyObject?)
	func showHelp(_ topics: [HelpTopic])
}

/// Implemented by objects that need to response to changes related to files
protocol FileHandler: class {
	/// Select the specified file
	///
	/// - Parameter file: the file to select
	func select(file: File)

	/// Updates data for file changes
	///
	/// - Parameter changes: the file changes
	func filesRefreshed(_ changes: [CollectionChange<File>]?)

	/// prompts the user to import file(s)
	///
	/// - Parameter sender: the sender of the import. unused
	func promptToImportFiles(_ sender: Any?)

	/// called to validate any menu items the FileHandler uses
	///
	/// - Parameter menuItem: the menu item to validate
	/// - Returns: true if the menu item was handled
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
}
