//
//  ZDebug.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

var gPrintMode: [ZPrintMode] = [.dTime]
var gDebugMode: [ZDebugMode] = []

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let   dNewUser = ZDebugMode() // exercise new-user, first-time arrival code

	var description: String {
		return [(.dNewUser, " new user")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}

}

struct ZPrintMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZPrintMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let   dNone = ZPrintMode()
	static let    dOps = ZPrintMode()
	static let    dLog = ZPrintMode()
	static let   dTime = ZPrintMode()
	static let   dInfo = ZPrintMode()
	static let   dEdit = ZPrintMode()
	static let   dFile = ZPrintMode()
	static let   dRing = ZPrintMode()
	static let   dText = ZPrintMode()
	static let   dUser = ZPrintMode()
	static let  dNames = ZPrintMode()
	static let  dFocus = ZPrintMode()
	static let  dSpeed = ZPrintMode()
	static let  dNotes = ZPrintMode()
	static let  dError = ZPrintMode()
	static let  dAdopt = ZPrintMode()
	static let  dFetch = ZPrintMode()
	static let dAccess = ZPrintMode()
	static let dSearch = ZPrintMode()
	static let dImages = ZPrintMode()
	static let dTimers = ZPrintMode()
	static let dRemote = ZPrintMode()

	var description: String {
		return [(.dOps,    "     op"),
				(.dLog,    "    log"),
				(.dFile,   "   file"),
				(.dTime,   "   time"),
				(.dEdit,   "   edit"),
				(.dInfo,   "   info"),
				(.dRing,   "   info"),
				(.dText,   "   text"),
				(.dUser,   "   user"),
				(.dNames,  "   name"),
				(.dNotes,  "   note"),
				(.dFocus,  "  focus"),
				(.dSpeed,  "  speed"),
				(.dError,  "  error"),
				(.dAdopt,  "  adopt"),
				(.dFetch,  "  fetch"),
				(.dAccess, " access"),
				(.dSearch, " search"),
				(.dImages, " images"),
				(.dRemote, " remote"),
				(.dTimers, " timers")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}

	static func toggle(_ mode: ZPrintMode) {
		if  let index = gPrintMode.index(of: mode) {
			gPrintMode.remove(at: index)
		} else {
			gPrintMode.append(mode)
		}
	}

}

