//
//  DefaultDockerAPISpec.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Quick
import Nimble
@testable import DockerSupport
import Mockingjay
import Result
import ReactiveSwift
import ClientCore

// TODO: create container
// TODO: load images

class DefaultDockerAPISpec: QuickSpec {
	override func spec() {
		var sessionConfig: URLSessionConfiguration!
		var api: DockerAPIImplementation!
		var globalQueue: DispatchQueue!
		let commonPrep = {
			globalQueue = DispatchQueue.global()
			sessionConfig = URLSessionConfiguration.default
			if !(sessionConfig.protocolClasses?.contains(where: {$0 == MockingjayProtocol.self}) ?? false) {
				sessionConfig.protocolClasses = [MockingjayProtocol.self, DockerUrlProtocol.self] as [AnyClass] + sessionConfig.protocolClasses!
			}
			api = DockerAPIImplementation(baseUrl: URL(string:"http://10.0.1.9:2375")!, sessionConfig: sessionConfig)
		}

		describe("use docker api") {
			it("should load version information") {
				commonPrep()
				self.stubGetRequest(uriPath: "/version", fileName: "version")
				let result = self.makeValueRequest(producer: api.loadVersion(), queue: globalQueue)
				expect(result.error).to(beNil())
				expect(result.value?.major).to(equal(1))
				expect(result.value?.minor).to(equal(12))
				expect(result.value?.fix).to(equal(1))
				expect(result.value?.apiVersion).to(beCloseTo(1.24))
			}
			
			it("should fetch json") {
				commonPrep()
				self.stubGetRequest(uriPath: "/test/json", fileName: "version")
				let result = self.makeValueRequest(producer: api.fetchJson(url: api.baseUrl.appendingPathComponent("/test/json")), queue: globalQueue)
				expect(result.error).to(beNil())
				expect(result.value).toNot(beNil())
				let json = result.value!
				expect(json["ApiVersion"]).to(equal("1.24"))
			}

			it("should refresh containers") {
				commonPrep()
				self.stubGetRequest(uriPath: "/containers/json", fileName: "containers")
				let result = self.loadContainers(api: api, queue: globalQueue)
				expect(result.error).to(beNil())
				expect(result.value).toNot(beNil())
				let containers = result.value!
				expect(containers).to(haveCount(3))
				expect(containers[.dbserver]).toNot(beNil())
				expect(containers[.dbserver]?.imageName).to(equal("rc2server/dbserver"))
				expect(containers[.dbserver]?.mountPoints).to(haveCount(1))
				expect(containers[.dbserver]?.mountPoints.first?.destination).to(equal("/rc2"))
				expect(containers[.appserver]).toNot(beNil())
				expect(containers[.appserver]?.state.value).to(equal(ContainerState.created))
			}
			
			context("use the dbserver container") {
				var containers: [DockerContainer] = []
				var dbcontainer: DockerContainer!
				var scheduler: QueueScheduler!
				beforeEach {
					commonPrep()
					scheduler = QueueScheduler(name: "\(#file)\(#line)")
					self.stubGetRequest(uriPath: "/containers/json", fileName: "containers")
					containers = self.loadContainers(api: api, queue: globalQueue).value!
					guard let db = containers[.dbserver] else {
						fatalError("failed to load containers for testing")
					}
					dbcontainer = db
				}

				it("should correctly perform operations") {
					self.stub(self.postMatcher(uriPath: "/containers/rc2_dbserver/"), builder: http(204))
					for anOperation in DockerContainerOperation.all {
						let producer = api.perform(operation: anOperation, container: dbcontainer).observe(on: scheduler)
						let result = self.makeNoValueRequest(producer: producer, queue: globalQueue)
						expect(result.error).to(beNil())
					}
				}
				
				it("should perform operation on all containers") {
					//use a custom builder to count how many times a HTTPResponse is built
					var count: Int = 0
					let mybuilder: (URLRequest) -> Response = { req in
						count += 1
						return http(204)(req)
					}
					self.stub(self.postMatcher(uriPath: "/containers/rc2_dbserver/pause"), builder: mybuilder)
					self.stub(self.postMatcher(uriPath: "/containers/rc2_appserver/pause"), builder: mybuilder)
					self.stub(self.postMatcher(uriPath: "/containers/rc2_compute/pause"), builder: mybuilder)
					let producer = api.perform(operation: .pause, containers: containers).observe(on: scheduler)
					let group = DispatchGroup()
					globalQueue.async(group: group) {
						_ = producer.wait()
					}
					group.wait()
					expect(count).to(equal(containers.count))
				}
				
				it("should remove the container") {
					self.stub(uri(uri: "/containers/rc2_dbserver"), builder: http(204))
					let producer = api.remove(container: dbcontainer).observe(on: scheduler)
					let result = self.makeNoValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(beNil())
				}

				it("should fail to remove the container") {
					self.stub(uri(uri: "/containers/rc2_dbserver"), builder: http(404))
					let producer = api.remove(container: dbcontainer).observe(on: scheduler)
					let result = self.makeNoValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(matchError(DockerError.noSuchObject))
				}
			}
			
			context("test network operations") {
				it("network should exist") {
					self.stubGetRequest(uriPath: "/networks", fileName: "networks")
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.networkExists(name: "clientcore_default").observe(on: scheduler)
					let result = self.makeValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(beNil())
					expect(result.value).to(beTrue())
				}

				it("network should not exist") {
					self.stubGetRequest(uriPath: "/networks", fileName: "networks")
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.networkExists(name: "rc2_nonexistant").observe(on: scheduler)
					let result = self.makeValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(beNil())
					expect(result.value).to(beFalse())
				}
				
				it("create network") {
					self.stub(self.postMatcher(uriPath: "/networks/create"), builder:http(204))
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.create(network: "rc2_fakecreate").observe(on: scheduler)
					let result = self.makeNoValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(beNil())
				}

				it("create network fails") {
					self.stub(self.postMatcher(uriPath: "/networks/create"), builder:http(500))
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.create(network: "rc2_fakecreatefail").observe(on: scheduler)
					let result = self.makeNoValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).toNot(beNil())
				}
			}

			context("test volume operations") {
				let volumeChecker:(String) -> Result<Bool, DockerError> = { name in
					self.stubGetRequest(uriPath: "/volumes", fileName: "volumes")
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.volumeExists(name: name).observe(on: scheduler)
					return self.makeValueRequest(producer: producer, queue: globalQueue)
				}
				
				it("volume exists") {
					let result = volumeChecker("rc2_dbdata")
					expect(result.error).to(beNil())
					expect(result.value).to(beTrue())
				}
				
				it("volume does not exist") {
					let result = volumeChecker("rc2_dbdataNOT")
					expect(result.error).to(beNil())
					expect(result.value).to(beFalse())
				}

				it("create volume") {
					self.stub(self.postMatcher(uriPath: "/volumes/create"), builder:http(201))
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.create(volume: "rc2_fakevol").observe(on: scheduler)
					let result = self.makeNoValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(beNil())
				}
			}
			
			context("test images") {
				it("load images from big list") {
					self.stubGetRequest(uriPath: "/images/json", fileName: "complexImages")
					let scheduler = QueueScheduler(name: "\(#file)\(#line)")
					let producer = api.loadImages().observe(on: scheduler)
					let result = self.makeValueRequest(producer: producer, queue: globalQueue)
					expect(result.error).to(beNil())
				}
			}
		}
	}
	
	func makeValueRequest<T>(producer: SignalProducer<T, DockerError>, queue: DispatchQueue) -> Result<T, DockerError> {
		var result: Result<T, DockerError>!
		let group = DispatchGroup()
		queue.async(group: group) {
			result = producer.single()
		}
		group.wait()
		return result
	}

	func makeNoValueRequest(producer: SignalProducer<(), DockerError>, queue: DispatchQueue) -> Result<(), DockerError> {
		var result: Result<(), DockerError>?
		let group = DispatchGroup()
		queue.async(group: group) {
			result = producer.wait()
		}
		group.wait()
		return result!
	}
	
	func loadContainers(api: DockerAPI, queue:DispatchQueue) -> Result<[DockerContainer], DockerError> {
		let scheduler = QueueScheduler(name: "\(#file)\(#line)")
		let producer = api.refreshContainers().observe(on: scheduler)
		var result: Result<[DockerContainer], DockerError>?
		let group = DispatchGroup()
		
		 queue.async(group: group) {
			result = producer.single()
		}
		group.wait()
		guard let r = result else {
			fatalError("failed to get result from refreshContainers()")
		}
		return r
	}

	/// returns a custom matcher looking for a post request at the specified path
	func postMatcher(uriPath: String) -> (URLRequest) -> Bool {
		return { request in
			return request.httpMethod == "POST" && request.url!.path.hasPrefix(uriPath)
		}
	}
	
	/// uses Mockingjay to stub out a request for uriPath with the contents of fileName.json
	func stubGetRequest(uriPath: String, fileName: String) {
		let path : String = Bundle(for: type(of:self)).path(forResource: fileName, ofType: "json")!
		let resultData = try? Data(contentsOf: URL(fileURLWithPath: path))
		stub(uri(uri: uriPath), builder: jsonData(resultData!))
	}

}
