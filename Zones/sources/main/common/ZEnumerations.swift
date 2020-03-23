//
//  ZEnumerations.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/31/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum InterfaceStyle : String {
    case Dark, Light
    
    init() {
        let type = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"

        self = InterfaceStyle(rawValue: type)!
    }
}

enum ZRootID: String {
    case graph     = "root"
    case trash     = "trash"
    case destroy   = "destroy"
    case favorites = "favorites"
    case lost      = "lost and found"
}

enum ZCloudAccountStatus: Int {
    case none
    case begin
    case available
    case active
}

struct ZTinyDotType: OptionSet {
	let rawValue: Int

	init(rawValue: Int) {
		self.rawValue = rawValue
	}

	static let eIdea  = ZTinyDotType(rawValue: 0x0001)
	static let eEssay = ZTinyDotType(rawValue: 0x0002)
}

enum ZListGrowthMode: Int {
    case up
    case down
}

enum ZBrowsingMode: Int {
    case confined
    case cousinJumps
}

enum ZFileMode: Int {
    case localOnly
    case cloudOnly
    case all
}

enum ZWorkMode: Int {
    case noRedrawMode
    case startupMode
    case searchMode
    case graphMode
	case editIdeaMode
	case noteMode
    // case outlineMode
}

enum ZShortcutType: String {
	case bold      = "b"
	case underline = "u"
	case append    = "+"
	case plain     = " "
}

enum ZCountsMode: Int { // do not change the order, they are persisted
	case none
	case dots
	case fetchable
	case progeny
}

enum ZToolTipsLength: Int { // do not change the order, they are persisted
	case none
	case clip
	case full

	var rotated: ZToolTipsLength {
		if  self == .full {
			return .none
		}

		return ZToolTipsLength(rawValue: rawValue + 1)!
	}

}

enum ZOutlineLevelType: String {
    case capital = "A"
    case  number = "1"
    case   small = "a"
    case   roman = "i"

    var asciiValue: UInt32 { return rawValue.asciiValue }
    var level: Int {
		switch self {
			case .capital: return 0
			case .number:  return 1
			case .small:   return 2
			case .roman:   return 3
		}
    }
}

enum ZDatabaseID: String {
	case preferencesID = "preferences"
    case   favoritesID = "favorites"
    case    everyoneID = "everyone"
    case      sharedID = "shared"
    case        mineID = "mine"
	
	var identifier: String { return rawValue.substring(toExclusive: 1) }
	var index:        Int? { return self.databaseIndex?.rawValue }

    var userReadableString: String {
		switch self {
			case .everyoneID: return "public"
			case     .mineID: return "my"
			default:          return ""
		}
    }

    var databaseIndex: ZDatabaseIndex? {
		switch self {
			case .favoritesID: return .favoritesIndex
			case  .everyoneID: return .everyoneIndex
			case      .mineID: return .mineIndex
			default:           return nil
		}
    }

	static func convert(from timerID: ZTimerID) -> ZDatabaseID? {
		switch timerID {
			case .tWriteEveryone: return .everyoneID
			case .tWriteMinimal,
				 .tWriteMine:     return .mineID
			default:         return nil
		}
	}

    static func convert(from scope: CKDatabase.Scope) -> ZDatabaseID? {
		switch scope {
			case .public:  return .everyoneID
			case .private: return .mineID
			default:       return nil
		}
    }

    static func convert(from id: String) -> ZDatabaseID? {
		switch id {
			case "e": return .everyoneID
			case "m": return .mineID
			default:  return nil
		}
    }
    
    func isDeleted(dict: ZStorageDictionary) -> Bool {
        let    name = dict[.recordName] as? String
        
        return name == nil ? false : gRemoteStorage.cloud(for: self)?.manifest?.deleted?.contains(name!) ?? false
    }
    
}

enum ZDatabaseIndex: Int {
	case everyoneIndex
    case mineIndex
	case favoritesIndex

    
    var databaseID: ZDatabaseID? {
		switch self {
			case .favoritesIndex: return .favoritesID
			case .everyoneIndex:  return .everyoneID
			case .mineIndex:      return .mineID
		}
    }
}

struct ZDetailsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZDetailsViewID(rawValue: 0x0001)
    static let Preferences = ZDetailsViewID(rawValue: 0x0002)
    static let       Tools = ZDetailsViewID(rawValue: 0x0008)
    static let       Debug = ZDetailsViewID(rawValue: 0x0010)
    static let         All = ZDetailsViewID(rawValue: 0x001F)
}

enum ZInterruptionError : Error {
	case userInterrupted
}

enum ZCorner : Int {
	case topLeft
	case topRight
	case bottomLeft
	case bottomRight
}

enum ZStorageType: String {
    case lost            = "lostAndFound"    // general
    case bookmarks       = "bookmarks"
    case favorites       = "favorites"
    case manifest        = "manifest"
	case minimal         = "minimal"
	case destroy         = "destroy"
    case userID          = "user ID"
    case model           = "model"
    case graph           = "graph"
    case trash           = "trash"
    case date            = "date"

    case recordName      = "recordName"		 // zones
    case parentLink      = "parentLink"
    case attributes      = "attributes"
    case children        = "children"
    case progeny         = "progeny"
    case traits          = "traits"
    case access          = "access"
    case author          = "author"
	case essay           = "essay"
	case order           = "order"
    case color           = "color"
    case count           = "count"
    case needs           = "needs"
    case link            = "link"
	case name            = "name"
	case note            = "note"

	case format          = "format"          // traits
	case asset           = "asset"
    case time            = "time"
    case text            = "text"
    case data            = "data"
    case type            = "type"

    case deleted         = "deleted"         // ZManifest
}

enum ZSpecialsMenuType: String {
	case eCommand = "c"
	case eOption  = "o"
	case eShift   = "s"
	case eControl = "n"
	case eReturn  = "r"
	case eArrow   = "i"
	case eBack    = "k"
	case eCancel  = "\r"

	static var activeTypes: [ZSpecialsMenuType] { return [.eCommand, .eOption, .eShift, .eControl, eReturn, .eArrow, .eBack] }

	var both: (String, String) {
		switch self {
			case .eShift:   return ("⇧",  "Shift")
			case .eCancel:  return ("",   "Cancel")
			case .eControl: return ("^",  "Control")
			case .eCommand: return ("⌘",  "Command")
			case .eOption:  return ("⌥",  "Option")
			case .eReturn:  return ("􀅇", "Return")
			case .eArrow:   return ("⇨",  "⇨")
			case .eBack:    return ("⇦",  "⇦")
		}
	}

	var text: String {
		let (insert, _) = both

		return insert
	}

	var title: String {
		let (_, title) = both
		return title
	}

}

// MARK: - debug
// MARK: -

var gDebugMode: [ZDebugMode] = [.timers, .ops]

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var nextValue: Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let rawValue: Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let   none = ZDebugMode()
	static let    ops = ZDebugMode()
	static let    log = ZDebugMode()
	static let   info = ZDebugMode()
	static let   edit = ZDebugMode()
	static let   file = ZDebugMode()
	static let   ring = ZDebugMode()
	static let  names = ZDebugMode()
	static let  focus = ZDebugMode()
	static let  speed = ZDebugMode()
	static let  notes = ZDebugMode()
	static let  error = ZDebugMode()
	static let access = ZDebugMode()
	static let search = ZDebugMode()
	static let images = ZDebugMode()
	static let timers = ZDebugMode()

	var description: String {
		return [(.ops,    "     op"),
				(.log,    "    log"),
				(.file,   "   file"),
				(.edit,   "   edit"),
				(.info,   "   info"),
				(.ring,   "   info"),
				(.names,  "   name"),
				(.notes,  "   note"),
				(.focus,  "  focus"),
				(.speed,  "  speed"),
				(.error,  "  error"),
				(.access, " access"),
				(.search, " search"),
				(.images, " images"),
				(.timers, " timers")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}

	static func toggle(_ mode: ZDebugMode) {
		if  let index = gDebugMode.index(of: mode) {
			gDebugMode.remove(at: index)
		} else {
			gDebugMode.append(mode)
		}
	}
}
