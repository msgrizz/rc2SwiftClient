//
//  Constants.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import ClientCore

let Rc2ErrorDomain = "Rc2ErrorDomain"

extension Notification.Name {
	///The object can be either a HelpTopic or a String
	static let DisplayHelpTopic = Notification.Name("DisplayHelpTopicNotification")
	///The object is the FileImporter used
	static let FilesImported = Notification.Name("FilesImportedNotification")
}

struct LocalStrings {
	static let addFileMessage = "File Name: "
	static let addFileDefaultName = "Untitled"
	static let deleteFileWarning = "DeleteFileWarning"
	static let deleteFileWarningInfo = "DeleteFileWarningInfo"
	static let clearWorkspaceWarning = "ClearWorkspaceWarning"
	static let clearWorkspaceWarningInfo = "ClearWorkspaceInfo"
	
}

extension NSPasteboard.PasteboardType {
	static let file = NSPasteboard.PasteboardType("io.rc2.model.file")
	static let variable = NSPasteboard.PasteboardType("io.rc2.model.variable.json")
}

let ConsoleAttachmentImageSize = CGSize(width: 48, height: 48)

let HelpUrlBase = "http://www.rc2.io/help/library"
let HelpUrlFuncSeperator = "/html"

let VariableUpdatedBackgroundColor = PlatformColor.green
let VariableNormalBackgroundColor = PlatformColor.white
