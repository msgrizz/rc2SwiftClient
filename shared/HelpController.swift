//
//  HelpController.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import os

class HelpTopic: NSObject {
	let name:String
	let isPackage:Bool
	let title:String?
	let desc:String?
	let aliases:[String]?
	let subtopics:[HelpTopic]?
	let packageName:String
	
	///initializer for a package description
	init(name:String, subtopics:[HelpTopic]) {
		self.isPackage = true
		self.name = name
		self.packageName = name
		self.title = nil
		self.desc = nil
		self.aliases = nil
		self.subtopics = subtopics
	}
	
	///initializer for an actual topic
	init(name:String, packageName:String, title:String, aliases:String, description:String?) {
		self.isPackage = false
		self.name = name
		self.packageName = packageName
		self.title = title
		self.desc = description
		self.subtopics = nil
		self.aliases = aliases.components(separatedBy: ":")
	}
	
	///convience for sorting
	func compare(_ other: HelpTopic) -> Bool {
		return self.name.caseInsensitiveCompare(other.name) == .orderedAscending
	}
	
	///accesor function to be passed around as a closure
	static func subtopicsAccessor(_ topic:HelpTopic) -> [HelpTopic]? {
		return topic.subtopics
	}
}

class HelpController {
	static let sharedInstance = HelpController()
	fileprivate let db:FMDatabase
	
	let packages:[HelpTopic]
	let allTopics:Set<HelpTopic>
	let allTopicNames:Set<String>
	fileprivate let topicsByName:Dictionary<String, [HelpTopic]>
	
	///loads topics from storage
	init() {
		let dbpath = Bundle(for: type(of: self)).path(forResource: "helpindex", ofType: "db")
		do {
			db = FMDatabase(path: dbpath)
			db.open()
			var topsByPack = [String:[HelpTopic]]()
			var topsByName = [String:[HelpTopic]]()
			var all = Set<HelpTopic>()
			var names = Set<String>()
			let rs = try db.executeQuery("select package,name,title,aliases,desc from helptopic where name not like '.%' order by package, name COLLATE nocase ", values: nil)
			while rs.next() {
				guard let package = rs.string(forColumn: "package") else { continue }
				let topic = HelpTopic(name: rs.string(forColumn: "name"), packageName:package, title: rs.string(forColumn: "title"), aliases:rs.string(forColumn: "aliases"), description: rs.string(forColumn: "desc"))
				if topsByPack[package] == nil {
					topsByPack[package] = []
				}
				topsByPack[package]!.append(topic)
				all.insert(topic)
				for anAlias in (topic.aliases! + [topic.name]) {
					names.insert(anAlias);
					if var atops = topsByName[anAlias] {
						atops.append(topic)
					} else {
						topsByName[anAlias] = [topic]
					}
				}
			}
			var packs:[HelpTopic] = []
			topsByPack.forEach() { (key, ptopics) in
				let package = HelpTopic(name: key, subtopics: ptopics.sorted(by: { return $0.compare($1) }))
				packs.append(package)
			}
			self.packages = packs.sorted(by: { return $0.compare($1) })
			self.allTopics = all
			self.allTopicNames = names
			self.topicsByName = topsByName
		} catch let error as NSError {
			os_log("error loading help index: %{public}@", log: .app, type:.error, error)
			fatalError("failed to load help index")
		}
	}
	
	deinit {
		db.close()
	}
	
	func hasTopic(_ name:String) -> Bool {
		return allTopicNames.contains(name)
	}
	
	fileprivate func parseResultSet(_ rs:FMResultSet) throws -> [HelpTopic] {
		var topicsByPack = [String:[HelpTopic]]()
		while rs.next() {
			guard let package = rs.string(forColumn: "package") else { continue }
			let topic = HelpTopic(name: rs.string(forColumn: "name"), packageName:package, title: rs.string(forColumn: "title"), aliases:rs.string(forColumn: "aliases"), description: rs.string(forColumn: "desc"))
			if topicsByPack[package] == nil {
				topicsByPack[package] = []
			}
			topicsByPack[package]!.append(topic)
		}
		let matches:[HelpTopic] = topicsByPack.map() { HelpTopic(name: $0, subtopics: $1) }
		return matches.sorted(by: { return $0.compare($1) })
	}
	
	func searchTopics(_ searchString:String) -> [HelpTopic] {
		guard searchString.characters.count > 0 else { return packages }
		var results:[HelpTopic] = []
		do {
			let rs = try db.executeQuery("select * from helpidx where helpidx match ?", values: [searchString])
			results = try parseResultSet(rs)
		} catch let error as NSError {
			os_log("error searching help: %{public}@", log: .app, error)
		}
		return results
	}
	
	//can't share code with initializer because functions can't be called in init before all properties are assigned
	func topicsWithName(_ targetName:String) -> [HelpTopic] {
		var packs:[HelpTopic] = []
		var topsByPack = [String:[HelpTopic]]()
		topicsByName[targetName]?.forEach() { aTopic in
			if var existPacks = topsByPack[aTopic.packageName] {
				existPacks.append(aTopic)
				topsByPack[aTopic.name] = existPacks
			} else {
				topsByPack[aTopic.packageName] = [aTopic]
			}
		}
		topsByPack.forEach() { (key, ptopics) in
			let package = HelpTopic(name: key, subtopics: ptopics.sorted(by: { return $0.compare($1) }))
			packs.append(package)
		}
		packs = packs.reduce([], { (pks, ht) in
			var myPacks = pks
			if ht.subtopics != nil { myPacks.append(contentsOf: ht.subtopics!) }
			return myPacks
		})
		packs = packs.sorted(by: { return $0.compare($1) })
		return packs
	}
	
	func topicsStartingWith(_ namePrefix:String) -> [HelpTopic] {
		var tops:[HelpTopic] = []
		topicsByName.forEach() { (tname, tarray) in
			if tname.hasPrefix(namePrefix) { tops += tarray }
		}
		return tops
	}
	
	func urlForTopic(_ topic:HelpTopic) -> URL {
		let str = "\(HelpUrlBase)/\(topic.packageName)\(HelpUrlFuncSeperator)/\(topic.name).html"
		return URL(string: str)!
	}
}
