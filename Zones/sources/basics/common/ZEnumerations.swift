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

enum ZMutateTextMenuType: String {
	case eCapitalize = "c"
	case eLower      = "l"
	case eUpper      = "u"
	case eCancel     = "."

	static var allTypes: [ZMutateTextMenuType] { return [.eCapitalize, .eLower, .eUpper, .eCancel] 	}

	var title: String {
		switch self {
			case .eCapitalize: return "capitalize"
			case .eLower:      return "lowercase"
			case .eUpper:      return "uppercase"
			case .eCancel:     return "cancel"
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

enum ZoneAttributeType: String {
	case invertColorize = "c"
	case validCoreData  = "v"
	case groupOwner     = "+"
}

enum ZRelayoutMapType: Int {
	case small
	case both
	case big
}

struct ZTinyDotType: OptionSet {
	let rawValue : Int
	
	init(rawValue: Int) { self.rawValue = rawValue }

	static let eIdea  = ZTinyDotType(rawValue: 1 << 0)
	static let eEssay = ZTinyDotType(rawValue: 1 << 1)
}
