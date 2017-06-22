//
//  SystemExtensions.swift
//
//  Copyright © 2016 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation

//FIXME: code smell
public func delay(_ delay: Double, _ closure:@escaping () -> Void) {
	DispatchQueue.main.asyncAfter(
		deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

// TODO: possibily get rid of NotificationCenter
public extension NotificationCenter {
	func postNotificationNameOnMainThread(_ name: NSNotification.Name, object: AnyObject, userInfo: [AnyHashable: Any]?=nil) {
		if !Thread.isMainThread {
			postAsyncNotificationNameOnMainThread(name, object: object, userInfo:userInfo)
		} else {
			post(name: name, object: object, userInfo: userInfo)
		}
	}
	func postAsyncNotificationNameOnMainThread(_ name: Notification.Name, object: AnyObject, userInfo: [AnyHashable: Any]?=nil) {
		DispatchQueue.main.async(execute: {
			self.post(name: name, object: object, userInfo: userInfo)
		})
	}
}

public extension NSRange {
	public func toStringRange(_ str: String) -> Range<String.Index>? {
		guard str.characters.count >= length - location && location < str.characters.count else { return nil }
		let fromIdx = str.characters.index(str.startIndex, offsetBy: self.location)
		guard let toIdx = str.characters.index(fromIdx, offsetBy: self.length, limitedBy: str.endIndex) else { return nil }
		return fromIdx..<toIdx
	}
}

public func MaxNSRangeIndex(_ range: NSRange) -> Int {
	return range.location + range.length - 1
}
