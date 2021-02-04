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
    case mapID       = "root"
    case trashID     = "trash"
    case destroyID   = "destroy"
	case recentsID   = "recents"
    case favoritesID = "favorites"
    case lostID      = "lost and found"
}

enum ZCloudAccountStatus: Int {
    case none
    case begin
    case available
    case active
}

enum ZStartupLevel: Int {
	case firstTime
	case localOkay
	case pleaseWait
	case pleaseEnableDrive
}

enum ZStartHereID: String {
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
	case swapDB  = "swapDB"
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

enum ZConfinementMode: String {
	case list = "List"
	case all  = "All"
}

enum ZListGrowthMode: String {
	case down = "Down"
    case up   = "Up"
}

enum ZSmallMapMode: String {
	case favorites = "Favorites"
	case recent    = "Recent"
}

enum ZFileMode: Int {
    case localOnly
    case cloudOnly
    case all
}

enum ZWorkMode: String {
	case editIdeaMode = "i"
	case startupMode  = "s"
    case searchMode   = "?"
	case mapsMode     = "g"
	case noteMode     = "n"
}

enum ZHelpMode: String {
	case mediumMode = "m"
	case basicMode  = "b"
	case noteMode   = "n"
	case allMode    = "a"
	case dotMode    = "d"
	case noMode     = " "

	var title: String {
		switch self {
			case .mediumMode: return "intermediate keys"
			case .basicMode:  return "basic keys"
			case .noteMode:   return "essay keys"
			case .allMode:    return "all keys"
			case .dotMode:    return "dots"
			default:          return ""
		}
	}

}

enum ZHelpType: String {
	case hPro       = "2"
	case hBold      = "!"
	case hDots      = "."
	case hSkip      = "="
	case hEmpty     = "-"
	case hPlain     = "0"
	case hInsert    = "+"
	case hMedium    = "1"
	case hUnderline = "_"
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
	case favoritesID = "favorites"
	case  everyoneID = "everyone"
	case   recentsID = "recents"
	case      mineID = "mine"

	var isSmallMapDB: Bool { return [.favoritesID, .recentsID].contains(self) }
	var identifier: String { return rawValue.substring(toExclusive: 1) }
	var index:        Int? { return self.databaseIndex?.rawValue }

	var zRecords: ZRecords? {
		switch self {
			case .favoritesID: return gFavorites
			case  .everyoneID: return gEveryoneCloud
			case   .recentsID: return gRecents
			case      .mineID: return gMineCloud
		}
	}

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
			case   .recentsID: return .recentsIndex
			case      .mineID: return .mineIndex
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
			case "r": return .recentsID
			case "m": return .mineID
			default:  return nil
		}
    }
    
    func isDeleted(dict: ZStorageDictionary) -> Bool {
        let    name = dict[.recordName] as? String
        
        return name == nil ? false : gRemoteStorage.cloud(for: self)?.manifest?.deletedRecordNames?.contains(name!) ?? false
    }

}

enum ZDatabaseIndex: Int { // N.B. do not change the order, these integer values are persisted
	case everyoneIndex
    case mineIndex
	case favoritesIndex
	case recentsIndex

    
    var databaseID: ZDatabaseID? {
		switch self {
			case .favoritesIndex: return .favoritesID
			case .everyoneIndex:  return .everyoneID
			case .recentsIndex:   return .recentsID
			case .mineIndex:      return .mineID
		}
    }
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
	case recent          = "recent"
    case model           = "model"
    case graph           = "graph"
    case trash           = "trash"
    case date            = "date"

    case recordName      = "recordName"		 // zones
    case parentLink      = "parentLink"
    case attributes      = "attributes"
    case children        = "children"
    case progeny         = "progeny"
	case strings         = "strings"
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

enum ZSpecialCharactersMenuType: String {
	case eCommand   = "c"
	case eOption    = "o"
	case eShift     = "s"
	case eControl   = "n"
	case eCopyright = "g"
	case eReturn    = "r"
	case eArrow     = "i"
	case eBack      = "k"
	case eCancel    = "\r"

	static var activeTypes: [ZSpecialCharactersMenuType] { return [.eCommand, .eOption, .eShift, .eControl, eReturn, .eCopyright, .eArrow, .eBack] }

	var both: (String, String) {
		switch self {
			case .eCopyright: return ("©",  "Copyright")
			case .eControl:   return ("^",  "Control")
			case .eCommand:   return ("⌘",  "Command")
			case .eOption:    return ("⌥",  "Option")
			case .eReturn:    return ("􀅇", "Return")
			case .eCancel:    return ("",   "Cancel")
			case .eShift:     return ("⇧",  "Shift")
			case .eArrow:     return ("⇨",  "⇨")
			case .eBack:      return ("⇦",  "⇦")
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

enum ZoneAttributeType: String {
	case invertColorize = "c"
	case validCoreData  = "v"
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

// MARK:- option sets
// MARK:-

struct ZTinyDotType: OptionSet {
	let rawValue: Int

	init(rawValue: Int) {
		self.rawValue = rawValue
	}

	static let eIdea  = ZTinyDotType(rawValue: 0x0001)
	static let eEssay = ZTinyDotType(rawValue: 0x0002)
}

struct ZFilterOption: OptionSet {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZFilterOption.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let fBookmarks = ZFilterOption()
	static let     fNotes = ZFilterOption()
	static let     fIdeas = ZFilterOption()
	static let      fNone = ZFilterOption([])
	static let       fAll = ZFilterOption(rawValue: 7)
}

struct ZDetailsViewID: OptionSet {
	let rawValue: Int

	init(rawValue: Int) {
		self.rawValue = rawValue
	}

	static let Preferences = ZDetailsViewID(rawValue: 0x0001)
	static let        Data = ZDetailsViewID(rawValue: 0x0002)
	static let   StartHere = ZDetailsViewID(rawValue: 0x0004)
	static let    SmallMap = ZDetailsViewID(rawValue: 0x0008)
	static let         All = ZDetailsViewID(rawValue: 0x000F)
}
