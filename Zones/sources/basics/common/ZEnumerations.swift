//
//  ZEnumerations.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/31/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum InterfaceStyle : String {
    case Dark, Light
    
    init() {
        let type = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"

        self = InterfaceStyle(rawValue: type)!
    }
}

struct ZHighlightStyle: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }
	
	static let sUltraThin = ZHighlightStyle(rawValue: 1 << 0)
	static let sDashed    = ZHighlightStyle(rawValue: 1 << 1)
	static let sMedium    = ZHighlightStyle(rawValue: 1 << 2)
	static let sThick     = ZHighlightStyle(rawValue: 1 << 3)
	static let sThin      = ZHighlightStyle(rawValue: 1 << 4)
	static let sNone      = ZHighlightStyle([])
}

enum ZRelayoutMapType: Int {
    case small
    case both
    case big
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

enum ZMigrationState: Int {
	case firstTime
	case migrate
	case normal
}

enum ZSimpleToolID: String {
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
	case tooltip = "tooltip"
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
	case wEditIdeaMode = "i"
	case wStartupMode  = "s"
    case wSearchMode   = "?"
	case wEssayMode    = "n"
	case wMapMode      = "g"
}

enum ZHelpMode: String {
	case middleMode = "m"
	case basicMode  = "b"
	case essayMode  = "e"
	case proMode    = "a"
	case dotMode    = "d"
	case noMode     = " "

	var title: String {
		switch self {
			case .middleMode: return "intermediate keys"
			case .essayMode:  return "notes & essays"
			case .basicMode:  return "basic keys"
			case .proMode:    return "all keys"
			case .dotMode:    return "dots"
			default:          return kEmpty
		}
	}

	func isEqual(to mode: ZHelpMode) -> Bool {
		return rawValue == mode.rawValue
	}

}

enum ZHelpType: String {
	case hPro       = "2"
	case hBold      = "!"
	case hDots      = "."
	case hSkip      = "="
	case hExtra     = "+"
	case hEmpty     = "-"
	case hBasic     = "0"
	case hIntermed  = "1"
	case hUnderline = "_"
}

enum ZCountsMode: Int { // do not change the order, they are persisted
	case none
	case dots
	case fetchable
	case progeny
}

enum ZMapLayoutMode: Int { // do not change the order, they are persisted
	case linearMode
	case circularMode

	var next: ZMapLayoutMode {
		switch self {
			case .linearMode: return .circularMode
			default:          return .linearMode
		}
	}

	var title: String {
		switch self {
		case .linearMode: return "Tree"
		default:          return "Star"
		}
	}
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

	var mapControlString: String {
		switch self {
			case .everyoneID: return "Mine"
			case     .mineID: return "Public"
			default:          return kEmpty
		}
	}

    var userReadableString: String {
		switch self {
			case .everyoneID: return "public"
			case     .mineID: return "my"
			default:          return kEmpty
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

    static func convert(from id: String?) -> ZDatabaseID? {
		guard id != nil else {
			return gDatabaseID
		}

		switch id {
			case "f": return .favoritesID
			case "e": return .everyoneID
			case "r": return .recentsID
			case "m": return .mineID
			default:  return nil
		}
    }
    
    func isDeleted(dict: ZStorageDictionary) -> Bool {
        let    name = dict[.recordName] as? String
        
        return name == nil ? false : gRemoteStorage.zRecords(for: self)?.manifest?.deletedRecordNames?.contains(name!) ?? false
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

	var cursor: NSCursor {
		switch self {
			case .bottom,
				 .top:  return .resizeUpDown
			case .right,
				 .left: return .resizeLeftRight
			default:    return kFourArrowsCursor ?? .crosshair
		}
	}

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

enum ZReorderMenuType: String {
	case eAlphabetical = "a"
	case eReversed     = "r"
	case eByLength     = "l"
	case eBySizeOfList = "s"
	case eByKind       = "k"

	static var activeTypes: [ZReorderMenuType] { return [.eReversed, .eByLength, .eAlphabetical, .eBySizeOfList, .eByKind] }

	var title: String {
		switch self {
			case .eAlphabetical: return "alphabetically"
			case .eReversed:     return "reverse order"
			case .eByLength:     return "by length of idea"
			case .eBySizeOfList: return "by size of list"
			case .eByKind:       return "by kind of idea"
		}
	}

}

enum ZRefetchMenuType: String {
	case eList    = "l"
	case eIdeas   = "g"
	case eAdopt   = "a"
	case eTraits  = "t"
	case eProgeny = "p"

	static var activeTypes: [ZRefetchMenuType] { return [.eIdeas, .eTraits, .eProgeny, .eList, .eAdopt] }

	var title: String {
		switch self {
			case .eList:    return "list"
			case .eAdopt:   return "adopt"
			case .eIdeas:   return "all ideas"
			case .eTraits:  return "all traits"
			case .eProgeny: return "all progeny"
		}
	}

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
	case idTitles
	case idBack
	case idSave
	case idHide

	static var all: [ZEssayButtonID] { return [.idBack, .idForward, .idSave, .idHide, .idDelete, .idCancel] }

	var title: String {
		switch self {
			case .idBack:    return "left.arrow"
			case .idForward: return "right.arrow"
			case .idCancel:  return "cancel"
			case .idDelete:  return "trash"
			case .idTitles:  return kEmpty
			case .idHide:    return "exit"
			case .idSave:    return "save"
		}
	}

	var tooltipString : String {
		let kind = (gCurrentEssay?.isNote ?? true) ? "note" : "essay"
		switch self {
			case .idForward: return "show next"
			case .idCancel:  return "cancel editing of \(kind)"
			case .idDelete:  return "delete"
			case .idTitles:  return kEmpty
			case .idHide:    return "hide \(kind)"
			case .idBack:    return "show previous"
			case .idSave:    return "save"
		}
	}

}

enum ZEssayTitleMode: Int {
	case sEmpty // do not change the order, storyboard and code dependencies
	case sTitle
	case sFull
}

enum ZoneAttributeType: String {
	case invertColorize = "c"
	case validCoreData  = "v"
	case groupOwner     = "+"
}

enum ZEssayLinkType: String {
	case hWeb   = "h"
	case hFile  = "u"
	case hIdea  = "i"
	case hNote  = "n"
	case hEssay = "e"
	case hEmail = "m"
	case hClear = "c"

	var title: String {
		switch self {
			case .hWeb:   return "Internet"
			case .hFile:  return "Upload"
			case .hIdea:  return "Idea"
			case .hNote:  return "Note"
			case .hEssay: return "Essay"
			case .hEmail: return "Email"
			case .hClear: return "Clear"
		}
	}

	var linkDialogLabel: String {
		switch self {
			case .hWeb:   return "Text of link"
			case .hEmail: return "Email address"
			default:      return "Name of file"
		}
	}

	var linkType: String {
		switch self {
			case .hWeb:   return "http"
			case .hEmail: return "mailto"
			default:      return title.lowercased()
		}
	}

	static var all: [ZEssayLinkType] { return [.hWeb, .hIdea, .hEmail, .hNote, .hEssay, .hFile, .hClear] }

}

// MARK: - option sets
// MARK: -

struct ZCirclesDisplayMode: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let cNone  = ZCirclesDisplayMode(rawValue: 0x0001)
	static let cIdeas = ZCirclesDisplayMode(rawValue: 0x0002)
	static let cRings = ZCirclesDisplayMode(rawValue: 0x0004)

	static func createFrom(_ set: IndexSet) -> ZCirclesDisplayMode {
		var mode = ZCirclesDisplayMode.cNone

		if  set.contains(0) {
			mode.insert(.cIdeas)
		}

		if  set.contains(1) {
			mode.insert(.cRings)
		}

		return mode
	}

	var indexSet: IndexSet {
		var set = IndexSet()

		if  contains(.cIdeas) {
			set.insert(0)
		}

		if  contains(.cRings) {
			set.insert(1)
		}

		return set
	}

}

struct ZoneType: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let zChildless = ZoneType(rawValue: 0x0001)
	static let zTrait     = ZoneType(rawValue: 0x0002)
	static let zNote      = ZoneType(rawValue: 0x0004)
	static let zDuplicate = ZoneType(rawValue: 0x0008)
	static let zBookmark  = ZoneType(rawValue: 0x0010)
}

struct ZTinyDotType: OptionSet {
	let rawValue : Int
	
	init(rawValue: Int) { self.rawValue = rawValue }

	static let eIdea  = ZTinyDotType(rawValue: 1 << 0)
	static let eEssay = ZTinyDotType(rawValue: 1 << 1)
}

struct ZDetailsViewID: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let vPreferences = ZDetailsViewID(rawValue: 0x0001)
	static let        vData = ZDetailsViewID(rawValue: 0x0002)
	static let vSimpleTools = ZDetailsViewID(rawValue: 0x0004)
	static let    vSmallMap = ZDetailsViewID(rawValue: 0x0008)
	static let   vSubscribe = ZDetailsViewID(rawValue: 0x0010)
	static let         vAll = ZDetailsViewID(rawValue: 0x001F)

	static let        vLast = vSmallMap
}

struct ZFilterOption: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }
	
	static let fBookmarks = ZFilterOption(rawValue: 1 << 0)
	static let     fNotes = ZFilterOption(rawValue: 1 << 1)
	static let     fIdeas = ZFilterOption(rawValue: 1 << 2)
	static let      fNone = ZFilterOption([])
	static let       fAll = ZFilterOption(rawValue: 7)
}
