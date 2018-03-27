//
//  CodeEditor.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Cocoa
import ClientCore
import Networking
import ReactiveSwift
import SyntaxParsing

enum EditorMode: Int {
	case notebook = 0
	case source
}

protocol CodeEditor: class, Searchable {
	var canExecute: Bool { get }
	func setContext(context: EditorContext)
	func executeSource(type: ExecuteType)
}

protocol EditorManager: CodeEditor {
	var canSwitchToNotebookMode: Bool { get }
	var canSwitchToSourceMode: Bool { get }
	func switchTo(mode: EditorMode)
}

/// object passed to UI controllers that take part in editing a document
protocol EditorContext: class {
	var currentDocument: Property<EditorDocument?> { get }
	var editorFont: MutableProperty<NSFont> { get }
	var notificationCenter: NotificationCenter { get }
	var workspaceNotificationCenter: NotificationCenter { get }
	var lifetime: Lifetime { get }
	
	func save(document: EditorDocument, isAutoSave: Bool) -> SignalProducer<String, Rc2Error>
	func load(file: AppFile?) -> SignalProducer<String?, Rc2Error>
}


