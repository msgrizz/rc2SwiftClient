//
//  BookmarkManager.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import SwiftyJSON

///manages access to Bookmarks and ServerHosts
public class BookmarkManager {
	///all existing bookmarks
	private(set) var bookmarks: [Bookmark] = []
	///bookmarks grouped by ServerHost.name
	private(set) var bookmarkGroups: [String:BookmarkGroup] = [:]
	///all known ServerHosts
	private(set) var hosts: [ServerHost] = []
	
	init() {
		loadBookmarks()
	}

	///saves bookmarks and hosts to NSUserDefaults
	func save() {
		let defaults = NSUserDefaults.standardUserDefaults()
		do {
			let bmarks = try JSON(bookmarks.map() { try $0.serialize() })
			defaults.setObject(bmarks.rawString(), forKey: PrefKeys.Bookmarks)
			let jhosts = try JSON(hosts.map() { try $0.serialize() })
			defaults.setObject(jhosts.rawString(), forKey: PrefKeys.Hosts)
		} catch let err {
			log.error("failed to serialize bookmarks: \(err)")
		}
	}
	
	///adds a new bookmark to bookmarks array
	func addBookmark(bookmark:Bookmark) {
		bookmarks.append(bookmark)
		bookmarks.sortInPlace() { $0.name < $1.name }
	}
	
	///loads bookmarks and hosts from NSUserDefaults
	private func loadBookmarks() {
		let defaults = NSUserDefaults.standardUserDefaults()
		bookmarks.removeAll()
		//load them, or create default ones
		if let bmstr = defaults.stringForKey(PrefKeys.Bookmarks) {
			for aJsonObj in JSON.parse(bmstr).arrayValue {
				bookmarks.append(Bookmark(json: aJsonObj)!)
			}
		}
		if bookmarks.count < 1 {
			bookmarks = createDefaultBookmarks()
		}
		bookmarks.sortInPlace() { $0.name < $1.name }
		//group them
		bookmarkGroups.removeAll()
		for aMark in bookmarks {
			addBookmarkToAppropriateGroup(aMark)
		}
		loadHosts()
	}
	
	private func addBookmarkToAppropriateGroup(bookmark:Bookmark) {
		let localKey = Constants.LocalBookmarkGroupName
		if let grp = bookmarkGroups[bookmark.server?.host ?? localKey] {
			bookmarkGroups[grp.key] = grp.addBookmark(bookmark)
		} else {
			bookmarkGroups[localKey] = BookmarkGroup(key: bookmark.server == nil ? localKey : bookmark.server!.name, firstBookmark: bookmark)
		}
	}
	
	///loads hosts from NSUserDefaults
	private func loadHosts() {
		let defaults = NSUserDefaults.standardUserDefaults()
		var hostSet = Set<ServerHost>()
		hosts.removeAll()
		if let hostsStr = defaults.stringForKey(PrefKeys.Hosts) {
			for aJsonObj in JSON.parse(hostsStr).arrayValue {
				hostSet.insert(ServerHost(json: aJsonObj)!)
			}
		}
		for aMark in bookmarks {
			if aMark.server != nil { hostSet.insert(aMark.server!) }
		}
		hosts.appendContentsOf(hostSet)
		hosts.sortInPlace() { $0.name < $1.name }
	}
	
	///returns an array of default bookmarks
	private func createDefaultBookmarks() -> [Bookmark] {
		let bmark = Bookmark(name:Constants.DefaultBookmarkName, server: nil, project: Constants.DefaultProjectName, workspace: Constants.DefaultWorkspaceName)
		return [bmark]
	}
}

///represents a collection of Bookmarks grouped by a key
struct BookmarkGroup {
	let key:String
	var bookmarks:[Bookmark] = []
	
	init(key:String, firstBookmark:Bookmark? = nil) {
		self.key = key
		if firstBookmark != nil { bookmarks.append(firstBookmark!) }
	}
	
	init(original:BookmarkGroup) {
		self.key = original.key
		self.bookmarks = original.bookmarks
	}
	
	func addBookmark(bmark:Bookmark) -> BookmarkGroup {
		return BookmarkGroup(original: self).addBookmark(bmark)
	}
}

