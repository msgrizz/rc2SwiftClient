//
//  BaseTest.swift
//  SwiftClient
//
//  Copyright © 2016 Mark Lilback. This file is licensed under the ISC license.
//

import XCTest
@testable import MacClient
import SwiftyJSON

class BaseTest: XCTestCase {

	var sessionData:LoginSession!
	var mockFM:MockFileManager!
	let serverHost:ServerHost = ServerHost(name: "local", host: "localhost", port: 8088, user: "local")
	
	override func setUp() {
		super.setUp()
		//setup filemanager with directory to trash
		mockFM = MockFileManager()
		
		let path : String = Bundle(for: RestServerTest.self).path(forResource: "loginResults", ofType: "json")!
		let resultData = try! Data(contentsOf: URL(fileURLWithPath: path))
		sessionData = LoginSession(json: JSON.init(data: resultData), host: "test")
	}
	
	override func tearDown() {
		mockFM = nil
		super.tearDown()
	}
	
	func workspaceForTesting() -> Workspace {
		let path : String = Bundle(for: type(of: self)).path(forResource: "createWorkspace", ofType: "json")!
		let json = try! String(contentsOfFile: path)
		let parsedJson = JSON.parse(json)
		let project = Project(json: parsedJson["projects"][0])
		return project.workspaces.first!
	}
	
	func fileUrlsForTesting() -> [URL] {
		let imgUrl = URL(fileURLWithPath: "/Library/Desktop Pictures/Art")
		let files = try! FileManager.default.contentsOfDirectory(at: imgUrl, includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: [.skipsHiddenFiles])
		return files
	}
}
