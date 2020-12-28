//
//  ZDebug.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

typealias ZDebugModes = [ZDebugMode]

var gDebugModes:  ZDebugModes = []
var gPrintModes: [ZPrintMode] = []

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let dNewUser     = ZDebugMode() // exercise new-user, first-time arrival code
	static let dUseFiles    = ZDebugMode() // read and write files
	static let dDebugAccess = ZDebugMode() // test write access by me not having full

	var description: String {
		return [(.dDebugAccess, "access"),
				(.dNewUser,     "arrival"),
				(.dUseFiles,    "use files")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}
}

extension ZDebugModes {
	var     newUser: Bool { return contains(.dNewUser) }
	var    useFiles: Bool { return contains(.dUseFiles) }
	var debugAccess: Bool { return contains(.dDebugAccess) }
}

struct ZPrintMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZPrintMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let   dNone = ZPrintMode()
	static let    dOps = ZPrintMode()
	static let    dFix = ZPrintMode()
	static let    dLog = ZPrintMode()
	static let   dTime = ZPrintMode()
	static let   dEdit = ZPrintMode()
	static let   dFile = ZPrintMode()
	static let   dText = ZPrintMode()
	static let   dUser = ZPrintMode()
	static let  dNames = ZPrintMode()
	static let  dFocus = ZPrintMode()
	static let  dSpeed = ZPrintMode()
	static let  dNotes = ZPrintMode()
	static let  dError = ZPrintMode()
	static let  dAdopt = ZPrintMode()
	static let  dFetch = ZPrintMode()
	static let  dCount = ZPrintMode()
	static let dAccess = ZPrintMode()
	static let dSearch = ZPrintMode()
	static let dRemote = ZPrintMode()
	static let dWidget = ZPrintMode()
	static let dImages = ZPrintMode()
	static let dTimers = ZPrintMode()
	static let dLevels = ZPrintMode()

	var description: String {
		return [(.dOps,    "     op"),
				(.dFix,    "    fix"),
				(.dLog,    "    log"),
				(.dFile,   "   file"),
				(.dTime,   "   time"),
				(.dEdit,   "   edit"),
				(.dText,   "   text"),
				(.dUser,   "   user"),
				(.dNames,  "   name"),
				(.dNotes,  "   note"),
				(.dFocus,  "  focus"),
				(.dSpeed,  "  speed"),
				(.dError,  "  error"),
				(.dAdopt,  "  adopt"),
				(.dFetch,  "  fetch"),
				(.dCount,  "  count"),
				(.dAccess, " access"),
				(.dSearch, " search"),
				(.dWidget, " widget"),
				(.dRemote, " remote"),
				(.dImages, " images"),
				(.dTimers, " timers"),
				(.dLevels, " levels")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}

	static func toggle(_ mode: ZPrintMode) {
		if  let index = gPrintModes.index(of: mode) {
			gPrintModes.remove(at: index)
		} else {
			gPrintModes.append(mode)
		}
	}

}

