//
//  ZEnumerations.swift
//  Seriously
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
    case graphID     = "root"
    case trashID     = "trash"
    case destroyID   = "destroy"
    case favoritesID = "favorites"
    case lostID      = "lost and found"
}

enum ZCloudAccountStatus: Int {
    case none
    case begin
    case available
    case active
}

enum ZSkillLevel: Int {
	case beginner
	case uncluttered
	case pro
}

enum ZIntroductionID: String {
	case up      = "up"
	case add     = "add"
	case edit    = "edit"
	case move    = "move"
	case idea    = "idea"
	case note    = "note"
	case down    = "down"
	case left    = "left"
	case child   = "child"
	case right   = "right"
	case focus   = "focus"
	case shift   = "shift"
	case showMe  = "showMe"
	case option  = "option"
	case command = "command"
	case control = "control"
	case sibling = "sibling"
}

enum ZMenuType: Int {
	case eUndo
	case eHelp
	case eSort
	case eFind
	case eColor
	case eChild
	case eAlter
	case eFiles
	case eCloud
	case eAlways
	case eParent
	case eTravel

	case eRedo
	case ePaste
	case eUseGrabs
	case eMultiple
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

enum ZFavoritesMode: Int {
	case favorites
	case recently
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
}

enum ZShortcutType: String {
	case bold      = "b"
	case insert    = "i"
	case power     = "p"
	case underline = "u"
	case append    = "a"
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

	var indicator: String {
		switch self {
			case .favoritesID: return "f"
			case  .everyoneID: return "e"
			case      .mineID: return "m"
			default:           return ""
		}
	}

    static func convert(from scope: CKDatabase.Scope) -> ZDatabaseID? {
		switch scope {
			case .public:  return .everyoneID
			case .private: return .mineID
			default:       return nil
		}
    }

    static func convert(from indicator: String) -> ZDatabaseID? {
		switch indicator {
			case "f": return .favoritesID
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

	static let  Preferences = ZDetailsViewID(rawValue: 0x0001)
    static let  Information = ZDetailsViewID(rawValue: 0x0002)
	static let Introduction = ZDetailsViewID(rawValue: 0x0004)
	static let       Status = ZDetailsViewID(rawValue: 0x0008)
	static let    Favorites = ZDetailsViewID(rawValue: 0x0010)
    static let          All = ZDetailsViewID(rawValue: 0x001F)
}

enum ZInterruptionError : Error {
	case userInterrupted
}

enum ZDirection : Int {
	case top
	case left
	case right
	case bottom
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

	case assetNames      = "assetNames"      // traits
	case assets          = "assets"
	case format          = "format"
    case time            = "time"
    case text            = "text"
    case data            = "data"
    case type            = "type"

    case deleted         = "deleted"         // ZManifest
}

enum ZSymbolsMenuType: String {
	case eCommand = "c"
	case eOption  = "o"
	case eShift   = "s"
	case eControl = "n"
	case eReturn  = "r"
	case eArrow   = "i"
	case eBack    = "k"
	case eCancel  = "\r"

	static var activeTypes: [ZSymbolsMenuType] { return [.eCommand, .eOption, .eShift, .eControl, eReturn, .eArrow, .eBack] }

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

enum ZEssayButtonID : Int {
	case idForward
	case idCancel
	case idDelete
	case idBack
	case idSave
	case idHide

	var title: String {
		switch self {
			case .idForward: return "⇨"
			case .idCancel:  return "Cancel"
			case .idDelete:  return "Delete"
			case .idHide:    return "Hide"
			case .idSave:    return "Save"
			case .idBack:    return "⇦"
		}
	}

	static var all: [ZEssayButtonID] { return [.idBack, .idForward, .idHide, .idSave, .idCancel, .idDelete] }
}

enum ZEssayHyperlinkType: String {
	case hWeb   = "h"
	case hIdea  = "i"
	case hNote  = "n"
	case hEssay = "e"
	case hClear = "c"

	var title: String {
		switch self {
			case .hWeb:   return "Internet"
			case .hIdea:  return "Idea"
			case .hNote:  return "Note"
			case .hEssay: return "Essay"
			case .hClear: return "Clear"
		}
	}

	var linkType: String {
		switch self {
			case .hWeb: return "http"
			default:    return title.lowercased()
		}
	}

	static var all: [ZEssayHyperlinkType] { return [.hWeb, .hIdea, .hNote, .hEssay, .hClear] }

}

// MARK: - debug
// MARK: -

var gDebugMode: [ZDebugMode] = [.dTime]

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let   dNone = ZDebugMode()
	static let    dOps = ZDebugMode()
	static let    dLog = ZDebugMode()
	static let   dTime = ZDebugMode()
	static let   dInfo = ZDebugMode()
	static let   dEdit = ZDebugMode()
	static let   dFile = ZDebugMode()
	static let   dRing = ZDebugMode()
	static let  dNames = ZDebugMode()
	static let  dFocus = ZDebugMode()
	static let  dSpeed = ZDebugMode()
	static let  dNotes = ZDebugMode()
	static let  dError = ZDebugMode()
	static let  dAdopt = ZDebugMode()
	static let  dFetch = ZDebugMode()
	static let dAccess = ZDebugMode()
	static let dSearch = ZDebugMode()
	static let dImages = ZDebugMode()
	static let dTimers = ZDebugMode()
	static let dRemote = ZDebugMode()

	var description: String {
		return [(.dOps,    "     op"),
				(.dLog,    "    log"),
				(.dFile,   "   file"),
				(.dTime,   "   time"),
				(.dEdit,   "   edit"),
				(.dInfo,   "   info"),
				(.dRing,   "   info"),
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

	static func toggle(_ mode: ZDebugMode) {
		if  let index = gDebugMode.index(of: mode) {
			gDebugMode.remove(at: index)
		} else {
			gDebugMode.append(mode)
		}
	}

}
