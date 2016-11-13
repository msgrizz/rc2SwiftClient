//
//  LoginFactory.swift
//
//  Copyright ©2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Freddy
import ReactiveSwift
import os

/// Factory class used to login and return a ConnectionInfo for that connection
// must subclass NSObject to be a delegate to URLSession api
public final class LoginFactory: NSObject {
	// MARK: - properties
	let sessionConfig: URLSessionConfiguration
	fileprivate var urlSession: URLSession?
	fileprivate var networkLog: OSLog! // we will create before init is complete
	fileprivate var loginResponse: URLResponse?
	fileprivate var responseData: Data
	fileprivate var signalObserver: Observer<ConnectionInfo, NetworkingError>?
	fileprivate var signalDisposable: Disposable?
	fileprivate var host: ServerHost?
	fileprivate var task: URLSessionDataTask?
	
	// MARK: - methods
	
	/// factory object to perform a login
	///
	/// - Parameter config: should include any necessary headers such as User-Agent
	public required init(config: URLSessionConfiguration = .default) {
		self.sessionConfig = config
		responseData = Data()
		super.init()
		urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
		networkLog = OSLog(subsystem: Bundle().bundleIdentifier ?? "io.rc2.client", category: "networking")
	}
	
	/// returns a SignalProducer to start the login process
	///
	/// - Parameters:
	///   - destHost: the host to connect to
	///   - login: the user's login name
	///   - password: the user's password
	/// - Returns: a signal producer that returns the ConnectionInfo or an Error
	public func login(to destHost: ServerHost, as login: String, password: String) -> SignalProducer<ConnectionInfo, NetworkingError>
	{
		assert(urlSession != nil, "login can only be called once")
		host = destHost
		guard let requestData = try? JSONSerialization.data(withJSONObject: ["login": login, "password": password], options: []) else
		{
			os_log("json serialization of login info failed", log: networkLog, type: .error)
			fatalError()
		}
		return SignalProducer<ConnectionInfo, NetworkingError>() { observer, disposable in
			self.signalObserver = observer
			self.signalDisposable = disposable
			let url = URL(string: "login", relativeTo: destHost.url!)!
			var request = URLRequest(url: url)
			request.httpMethod = "POST"
			request.addValue("application/json", forHTTPHeaderField: "Content-Type")
			request.addValue("application/json", forHTTPHeaderField: "Accept")
			request.httpBody = requestData
			self.task = self.urlSession?.dataTask(with: request)
			self.task?.resume()
		}
	}
	
	/// Cancels the outstanding login request
	public func cancel() {
		urlSession?.invalidateAndCancel()
		urlSession = nil
		task = nil
		signalObserver?.sendInterrupted()
		signalDisposable?.dispose()
	}
	
}

// MARK: - URLSessionDataDelegate implementation
extension LoginFactory: URLSessionDataDelegate {
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
	{
		loginResponse = response
		completionHandler(.allow)
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
	{
		responseData.append(data)
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
	{
		defer { self.task = nil; self.urlSession = nil }
		guard error == nil else {
			os_log("login error: %{public}s", log: networkLog, type: .default, error!.localizedDescription)
			signalObserver?.send(error: .connectionError(error!))
			return
		}
		do {
			let info = try ConnectionInfo(host: host!, json: try JSON(data: responseData))
			signalObserver?.send(value: info)
			signalObserver?.sendCompleted()
		} catch {
			os_log("error parsing login info: %{public}s", log: networkLog, type: .default, error.localizedDescription)
			signalObserver?.send(error: .invalidJson)
		}
	}
}
