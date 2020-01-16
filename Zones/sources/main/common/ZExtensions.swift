//
//  ZExtensions.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

typealias               ZoneArray = [Zone]
typealias        ZTraitDictionary = [ZTraitType : ZTrait]
typealias      ZStorageDictionary = [ZStorageType : NSObject]
typealias   ZAttributesDictionary = [NSAttributedString.Key : Any]
typealias ZStringObjectDictionary = [String : NSObject]
let                  gApplication = ZApplication.shared

func printFancy(_ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  let t = test, !t() { return }
	let fancy = (surround == nil) ? message : message.surround(with: surround!)
	FOREGROUND {
		print(fancy)
	}
}

func printDebug(_ mode: ZDebugMode, prefix: String = "  ", _ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  gDebugMode.contains(mode) {
		printFancy("\(mode): " + prefix + message, surround: surround, test)
	}
}

extension NSObject {


    func                  note(_ iMessage: Any?)                { } // logk(iMessage) }
    func           performance(_ iMessage: Any?)                { log(iMessage) }
    func                   bam(_ iMessage: Any?)                { log("-------------------------------------------------------------------- " + (iMessage as? String ?? "")) }
    func           redrawGraph(_ onCompletion: Closure? = nil)  { gControllers.signalFor(nil, regarding: .eRelayout, onCompletion: onCompletion) }
    func     printCurrentFocus()                                { gHere.widget?.printView() }

	func columnarReport(mode: ZDebugMode = .log, _ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(mode: mode, iFirst, iSecond) }

	func rawColumnarReport(mode: ZDebugMode = .log, _ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(kLogTabStop)
            printDebug(mode, "\(prefix)\(iSecond ?? "")")
        }
    }


    func log(_ iMessage: Any?) {
        if  let   message = iMessage as? String, message != "" {
            printDebug(.log, message)
        }
    }


    func time(of title: String, _ closure: Closure) {
        let start = Date()

        closure()

        let duration = Date().timeIntervalSince(start)

        columnarReport(title, duration)
    }


    func blankScreenDebug() {
        if  let w = gGraphController?.thoughtsRootWidget.bounds.size.width, w < 1.0 {
            bam("blank graph !!!!!!")
        }
    }
    
    
    func repeatUntil(_ isDone: @escaping ToBooleanClosure, then: @escaping Closure) {
        let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { iTimer in
            if  isDone() {
                iTimer.invalidate()
                then()
            }
        }
    }
    

    func syncAndRedraw(_ zone: Zone? = nil) {
        gControllers.sync(zone) {
            gControllers.signalFor(zone, regarding: .eRelayout, onCompletion: nil)
        }
    }
    

    func redrawAndSync(_ zone: Zone? = nil, _ onCompletion: Closure? = nil) {
        gControllers.syncToCloudAfterSignalFor(zone, regarding: .eRelayout, onCompletion: onCompletion)
    }
    

    func redrawSyncRedraw(_ zone: Zone? = nil, _ onCompletion: Closure? = nil) {
        redrawAndSync(zone) {
            gControllers.signalFor(zone, regarding: .eRelayout, onCompletion: onCompletion)
        }
    }


    @discardableResult func detectWithMode(_ dbID: ZDatabaseID, block: ToBooleanClosure) -> Bool {
        gRemoteStorage.pushDatabaseID(dbID)

        let result = block()

        gRemoteStorage.popDatabaseID()
        
        return result
    }


    func invokeUsingDatabaseID(_ dbID: ZDatabaseID?, block: Closure) {
        if  dbID != nil && dbID != gDatabaseID {
            detectWithMode(dbID!) { block(); return false }
        } else {
            block()
        }
    }


    func UNDO<TargetType : AnyObject>(_ target: TargetType, handler: @escaping (TargetType) -> Swift.Void) {
        kUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            handler(iTarget)
        })
    }


    func openBrowserForFocusWebsite() {
        "https://medium.com/@sand_74696/what-you-get-d565b064be7b".openAsURL()
    }

    
    func sendEmailBugReport() {
        "mailto:sand@gizmolab.com".openAsURL()
    }
    
    
    // MARK:- bookmarks
    // MARK:-


    func isValid(_ iLink: String?) -> Bool {
        return components(of: iLink) != nil
    }


    func components(of iLink: String?) -> [String]? {
        if  let       link = iLink {
            let components =  link.components(separatedBy: kSeparator)
            if  components.count > 2 {
                return components
            }
        }

        return nil
    }


    func recordName(from iLink: String?) -> String? {
        if  let components = components(of: iLink) {
            let      name  = components[2]
            return   name != "" ? name : kRootName // by design: empty component means root
        }

        return nil
    }


    func databaseID(from iLink: String?) -> ZDatabaseID? {
        if  let components = components(of: iLink) {
            let      dbID  = components[0]
            return   dbID == "" ? nil : ZDatabaseID(rawValue: dbID)
        }

        return nil
    }


    func zoneFrom(_ iLink: String?) -> Zone? {
        if  iLink                   != nil,
            iLink                   != "",
            let                 name = recordName(from: iLink) {
            let components: [String] = iLink!.components(separatedBy: kSeparator)
            let recordID: CKRecord.ID = CKRecord.ID(recordName: name)
            let ckRecord: CKRecord   = CKRecord(recordType: kZoneType, recordID: recordID)
            let        rawIdentifier = components[0]
            let   dbID: ZDatabaseID? = rawIdentifier == "" ? gDatabaseID : ZDatabaseID(rawValue: rawIdentifier)
            let             zRecords = gRemoteStorage.zRecords(for: dbID)
            let                 zone = zRecords?.zone(for: ckRecord) ?? Zone(record: ckRecord, databaseID: dbID) // BAD DUMMY ?

            return zone
        }

        return nil
    }


    // MARK:- JSON
    // MARK:-


    func dictFromJSON(_ dict: ZStringObjectDictionary) -> ZStorageDictionary {
        var                   result = ZStorageDictionary ()

        for (key, value) in dict {
            if  let       storageKey = ZStorageType(rawValue: key) {
                var        goodValue = value
                var       translated = false

                if  let string       = value as? String {
                    let parts        = string.components(separatedBy: kTimeInterval + kSeparator)
                    if  parts.count > 1,
                        parts[0]    == "",
                        let interval = TimeInterval(parts[1]) {
                        goodValue    = Date(timeIntervalSinceReferenceDate: interval) as NSObject
                        translated   = true
                    }
                }

                if !translated {
                    if  let     subDict = value as? ZStringObjectDictionary {
                        goodValue       = dictFromJSON(subDict) as NSObject
                    } else if let array = value as? [ZStringObjectDictionary] {
                        var   goodArray = [ZStorageDictionary] ()

                        for subDict in array {
                            goodArray.append(dictFromJSON(subDict))
                        }

                        goodValue       = goodArray as NSObject
                    }
                }

                result[storageKey]  = goodValue
            }
        }

        return result
    }


    func jsonDictFrom(_ dict: ZStorageDictionary) -> ZStringObjectDictionary {
        var    last = ZStorageDictionary ()
        var  result = ZStringObjectDictionary ()

        let closure = { (key: ZStorageType, value: Any) in
            var goodValue       = value
            if  let     subDict = value as? ZStorageDictionary {
                goodValue       = self.jsonDictFrom(subDict)
            } else if let  date = value as? Date {
                goodValue       = kTimeInterval + ":\(date.timeIntervalSinceReferenceDate)"
            } else if let array = value as? [ZStorageDictionary] {
                var jsonArray   = [ZStringObjectDictionary] ()

                for subDict in array {
                    jsonArray.append(self.jsonDictFrom(subDict))
                }

                goodValue       = jsonArray
            }

            result[key.rawValue]   = (goodValue as! NSObject)
        }

        for (key, value) in dict {
            if [.children, .traits].contains(key) {
                last[key] = value
            } else {
                closure(key, value)
            }
        }

        for (key, value) in last {
            closure(key, value)
        }

        return result
    }

}
//
//
//extension CKRecord.Reference {
//    
//
//    func storageDictionary() -> ZStorageDictionary {
//        var          dict = ZStorageDictionary()
//        dict[.recordName] = recordID.recordName as NSObject
//        
//        return dict
//    }
//    
//    
//    class func create(with dict: ZStorageDictionary, for iDatabaseID: ZDatabaseID) -> CKRecord.Reference? {
//        if  let name = dict[.recordName] as? String {
//            let id = CKRecord.ID(recordName: name)
//            
//            return CKRecord.Reference(recordID: id, action: .none)
//        }
//        
//        return nil
//    }
//    
//}


extension CKRecord {
    
    
    var reference: CKRecord.Reference { return CKRecord.Reference(recordID: recordID, action: .none) }
    
    
    var isEmpty: Bool {
        for key in [kpZoneName, kpParent, kpZoneParentLink] {
            if  self[key] != nil {
                return false
            }
        }

        return true
    }
    

    var isBookmark: Bool {
        if  let    link = self[kpZoneLink] as? String {
            return link.contains(kSeparator)
        }

        return false
    }


    var decoratedName: String {
		switch recordType {
			case kTraitType:
				let text = self["text"] as? String ?? kNoValue
				return    (self["type"] as? String ?? "") + " " + text
			case kZoneType:
				if  let      name = self[kpZoneName] as? String {
					let separator = " "
					var    prefix = ""
					
					if  isBookmark {
						prefix.append("L")
					}
					
					if  let fetchable = self[kpZoneCount] as? Int, fetchable > 1 {
						if  prefix != "" {
							prefix.append(separator)
						}
						
						prefix.append("\(fetchable)")
					}
					
					if  prefix != "" {
						prefix  = "(" + prefix + ")  "
					}
					
					return prefix.appending(name)
			}
			default:
				return recordID.recordName
		}

        return kNoValue
    }


    convenience init(for name: String) {
        self.init(recordType: kZoneType, recordID: CKRecord.ID(recordName: name))
    }

    
    func isDeleted(dbID: ZDatabaseID) -> Bool {
        return gRemoteStorage.cloud(for: dbID)?.manifest?.deleted?.contains(recordID.recordName) ?? false
    }


    @discardableResult func copy(to iCopy: CKRecord?, properties: [String]) -> Bool {
        var  altered = false
        if  let copy = iCopy {
            for keyPath in properties {
                let        leftSide = copy[keyPath]
                let       rightSide = self[keyPath]
                if  leftSide?.hash != rightSide?.hash {
                    copy[keyPath]   = rightSide
                    altered         = true
                }
            }
        }

        return altered
    }


    func hasKey(_ key: String) -> Bool {
        return allKeys().contains(key)
    }


    func index(within iReferences: [CKRecord.ID]) -> Int? {
        for (index, identifier) in iReferences.enumerated() {
            if  identifier == recordID {
                return index
            }
        }

        return nil
    }


    func maybeMarkAsFetched(_ databaseID: ZDatabaseID?) {
        let states        = [ZRecordState.notFetched, ZRecordState.needsFetch]
        if  creationDate != nil,
            let dbID      = databaseID,
            let manager   = gRemoteStorage.cloud(for: dbID),
            manager.hasCKRecord(self, forAnyOf: states) {
            manager.clearCKRecords([self], for: states)
        }
    }

}


extension BlockOperation {
    
    func invokeCompletions() {
        if  let block = completionBlock {
            block()
        }
        
//        if  let recordBlock = perRecordCompletionBlock {
//            recordBlock()
//        }
    }
    
}


infix operator ** : MultiplicationPrecedence


extension Double {
    static func ** (base: Double, power: Double) -> Double{
        return pow(base, power)
    }
}


infix operator -- : AdditionPrecedence


extension CGPoint {

    public init(_ size: CGSize) {
        self.init()

        x = size.width
        y = size.height
    }


    static func - ( left: CGPoint, right: CGPoint) -> CGSize {
        return CGSize(width: left.x - right.x, height: left.y - right.y)
    }


    static func -- ( left: CGPoint, right: CGPoint) -> CGFloat {
        let  width = Double(left.x - right.x)
        let height = Double(left.y - right.y)

        return CGFloat(sqrt(width * width + height * height))
    }

}


extension CGSize {

    var hypontenuse: CGFloat {
        return sqrt(width * width + height * height)
    }

    static var big: CGSize {
        return CGSize(width: 1000000, height: 1000000)
    }

	func offsetBy(_ x: CGFloat, _ y: CGFloat) -> CGSize {
		return CGSize(width: width + x, height: height + y)
	}

	func force(horizotal: Bool, into range: NSRange) -> CGSize {
		if  horizotal {
			let value = max(min(width,  CGFloat(range.upperBound)), CGFloat(range.lowerBound))
			return CGSize(width: value, height: height)
		} else {
			let value = max(min(height, CGFloat(range.upperBound)), CGFloat(range.lowerBound))
			return CGSize(width: width, height: value)
		}
	}

}


extension CGRect {

    var    center: CGPoint { return CGPoint(x: midX, y: midY) }
    var    extent: CGPoint { return CGPoint(x: maxX, y: maxY) }
    

    public init(start: CGPoint, end: CGPoint) {
        self.init()

        size   = end - start
        origin = start

        if  size .width < 0 {
            size .width = -size.width
            origin   .x = end.x
        }

        if  size.height < 0 {
            size.height = -size.height
            origin   .y = end.y
        }
    }


    func indices(within iBounds: CGRect, radix: Int) -> IndexSet {
        let c = center
        var set = IndexSet()

        set.insert(Int(c.x))

        return set
    }

    
    func offsetBy(fractionX: CGFloat, fractionY: CGFloat) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY
        
        return offsetBy(dx:dX, dy:dY)
    }

    
    func insetBy(fractionX: CGFloat, fractionY: CGFloat) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY

        return insetBy(dx:dX, dy:dY)
    }

}


extension Array {


    func apply(closure: AnyToStringClosure) -> String {
        var separator = ""
        var    string = ""

        for object in self {
            if let message = closure(object) {
                string.append("\(separator)\(message)")

                if  separator.isEmpty {
                    separator.appendSpacesToLength(kLogTabStop)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }

    
    func containsCompare(with other: AnyObject, using: CompareClosure? = nil) -> Bool {
        if  let compare = using {
            for item in self {
                if  compare(item as AnyObject, other) {
                    return true     // true means match
                }
            }
        }
        
        return false    // false means unique
    }
    

    mutating func appendUnique(contentsOf items: Array, compare: CompareClosure? = nil) {
        let array = self as NSArray
        
        for item in items {
            if  !array.contains(item),
                !containsCompare(with: item as AnyObject, using: compare) {
                append(item)
            }
        }
    }

    
    func intersection<S>(_ other: Array<Array<Element>.Element>) -> S where Element: Hashable {
        return Array(Set(self).intersection(Set(other))) as! S
    }
    
}


extension Array where Element == Zone {


    func updateOrder() { updateOrdering(start: 0.0, end: 1.0) }
    
    
    func orderLimits() -> (start: Double, end: Double) {
        var start = 1.0
        var   end = 0.0
        
        for zone in self {
            let  order = zone.order
            let  after = order > end
            let before = order < start
            
            if  before {
                start  = order
            }
            
            if  after {
                end    = order
            }
        }
        
        return (start, end)
    }
    
    
    func sortedByReverseOrdering() -> Array {
        return sorted { (a, b) -> Bool in
            return a.order > b.order
        }
    }
    
    
    func updateOrdering(start: Double, end: Double) {
        let increment = (end - start) / Double(self.count + 2)
        
        for (index, child) in self.enumerated() {
            let newOrder = start + (increment * Double(index + 1))
            let    order = child.order
            
            if  order      != newOrder {
                child.order = newOrder
                
                child.maybeNeedSave()
            }
        }
        
        gSelecting.updateCousinList()
    }
    

    func traverseAncestors(_ block: ZoneToStatusClosure) {
        for zone in self {
            zone.safeTraverseAncestors(visited: [], block)
        }
    }

    
    func traverseAllAncestors(_ block: @escaping ZoneClosure) {
        for zone in self {
            zone.safeTraverseAncestors(visited: []) { iZone -> ZTraverseStatus in
                block(iZone)
                
                return .eContinue
            }
        }
    }
    
    
    func rootMost(goingUp: Bool) -> Zone? {
        guard count > 0 else { return nil }

        var      candidate = first
        
        if count > 1 {
            var candidates = [Zone] ()
            var      level = candidate?.level ?? 100
            var      order = goingUp ? 1.0 : 0.0

            for zone in self {
                if  level      == zone.level {
                    candidates.append(zone)
                } else {
                    candidate   = zone
                    level       = candidate!.level
                    candidates  = [candidate!]
                }
            }
            
            for zone in candidates {
                let    zOrder = zone.order

                if  goingUp  ? (zOrder < order) : (zOrder > order) {
                    order     = zOrder
                    candidate = zone
                }
            }
        }
        
        return candidate
    }


    var rootMost: Zone? {
        var candidate: Zone?
        
        for zone in self {
            if  candidate == nil || zone.level < candidate!.level {
                candidate = zone
            }
        }
        
        return candidate
    }

}

extension NSRange {

	func offsetBy(_ offset: Int) -> NSRange { return NSRange(location: offset + location, length: length) }

	func inclusiveIntersection(_ other: NSRange, includeUpper: Bool = true) -> NSRange? {
		if  let    i = intersection(other) {
			return i
		}

		if  location == other.location || (location == other.upperBound && includeUpper) {
			return NSRange(location: location, length: other.upperBound - location)
		}

		return nil
	}

}

extension NSTextTab {

	var string: String {
		return kAlignment + kLevelSixSeparator + "\(alignment.rawValue)" + kLevelFiveSeparator + kLocation + kLevelSixSeparator + "\(location)"
	}

	convenience init(string: String) {
		var location: CGFloat = 0.0
		var alignment = NSTextAlignment.natural

		let parts = string.components(separatedBy: kLevelFiveSeparator)

		for part in parts {
			let subparts = part.components(separatedBy: kLevelSixSeparator)
			let    value = subparts[1]
			switch subparts[0] {
				case kLocation:  if let v = value.floatValue                                         { location  = v }
				case kAlignment: if let v = value.integerValue, let a = NSTextAlignment(rawValue: v) { alignment = a }
				default: break
			}
		}

		self.init(textAlignment: alignment, location: location, options: [:])
	}
}

extension NSMutableParagraphStyle {

	var string: String {
		var result = kAlignment + kLevelThreeSeparator + "\(alignment.rawValue)"

		if  let stops = tabStops {
			result.append(kLevelTwoSeparator + kStops)

			for stop in stops {
				result.append(kLevelThreeSeparator + stop.string)
			}
		}

		return result
	}

	convenience init(string: String) {
		self.init()

		let parts = string.components(separatedBy: kLevelTwoSeparator)

		for part in parts {
			let subparts = part.components(separatedBy: kLevelThreeSeparator)

			if  subparts.count > 1 {
				switch subparts[0] {
					case kAlignment:
						if  let   raw = subparts[1].integerValue,
							let     a = NSTextAlignment(rawValue: raw) {
							alignment = a
						}
					case kStops:
						let string = subparts[1]
						let   stop = NSTextTab(string: string)
						tabStops   = [stop]
					default: break
				}
			}
		}
	}

}


extension ZFont {

	var string: String { return fontDescriptor.string }

	convenience init(string: String) {
		let descriptor = NSFontDescriptor(string: string)

		self.init(descriptor: descriptor, textTransform: nil)!
	}
}


extension NSFontDescriptor {

	var string: String {
		var result = ""
		var separator = ""

		for (name, attribute) in fontAttributes {
			result.append(separator + name.rawValue + kLevelThreeSeparator + "\(attribute)")
			separator = kLevelTwoSeparator
		}

		return result
	}

	convenience init(string: String) {
		let parts = string.revised.components(separatedBy: kLevelTwoSeparator)
		var dict  = [NSFontDescriptor.AttributeName : Any]()

		for part in parts {
			let subparts   = part.components(separatedBy: kLevelThreeSeparator)
			if  subparts.count > 1 {
				let    key = subparts[0]
				let  value = subparts[1]
				let   name = NSFontDescriptor.AttributeName(key)

				dict[name] = value
			}
		}

		self.init(fontAttributes: dict)
	}
}

extension NSMutableAttributedString {

	var allKeys: [NSAttributedString.Key] { return [.font, .link, .paragraphStyle, .foregroundColor, .backgroundColor] }

	var attributesAsString: String {
		get { return attributeStrings.joined(separator: kLevelOneSeparator) }
		set { attributeStrings = newValue.components(separatedBy: kLevelOneSeparator) }
	}

	var attributeStrings: [String] {
		get {
			var result = [String]()
			let  range = NSRange(location: 0, length: length)

			for key in allKeys {
				enumerateAttribute(key, in: range, options: .reverse) { (item, inRange, flag) in
					var string: Any?

					if  let value      = item {
						if  let   font = value as? ZFont {
							string     = font.string
						}

						if  key       == .link {
							string     = "\(value)"
						}

						if  let  color = value as? NSColor {
							string     = color.string
						}

						if  let  style = value as? NSMutableParagraphStyle {
							string     = style.string
						}

						if  let append = string as? String {
							result.append("\(inRange.location)" + kLevelFourSeparator + "\(inRange.length)" + kLevelFourSeparator + key.rawValue + kLevelFourSeparator + append)
						}
					}
				}
			}

			return result
		}

		set {
			for string in newValue {
				let      parts = string.components(separatedBy: kLevelFourSeparator)
				if       parts.count > 3,
					let  start = parts[0].integerValue,
					let  count = parts[1].integerValue {
					let    raw = parts[2]
					let string = parts[3]
					let    key = NSAttributedString.Key(rawValue: raw)
					let  range = NSRange(location: start, length: count)
					var attribute: Any?

					switch key {
						case .link:            attribute =                                 string
						case .font:            attribute = ZFont 				  (string: string)
						case .foregroundColor: attribute = ZColor				  (string: string)
						case .paragraphStyle:  attribute = NSMutableParagraphStyle(string: string)
						default:    		   break
					}

					if  let value = attribute {
						printDebug(.essay, "add attribute over \(range) for \(raw): \(value)")

						addAttribute(key, value: value, range: range)
					}
				}
			}
		}
	}

	func removeAllAttributes() {
		let range = NSRange(location: 0, length: length)

		for key in allKeys {
			removeAttribute(key, range: range)
		}
	}

	func fixAllAttributes() {
		fixAttributes(in: NSRange(location: 0, length: self.length))
	}

}

extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var   asciiValue:  UInt32  { return asciiArray[0] }
    var           length: Int  { return unicodeScalars.count }
    var          isDigit: Bool { return "0123456789.+-=*/".contains(self[startIndex]) }
    var   isAlphabetical: Bool { return "abcdefghijklmnopqrstuvwxyz".contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
    var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
    var       isOpposite: Bool { return "]}>)".contains(self) }

	var revised: String {
		return replacingOccurrences(of: kOldLevelOneSeparator, with: kLevelOneSeparator)
		.replacingOccurrences(of: kOldLevelTwoSeparator, with: kLevelTwoSeparator)
		.replacingOccurrences(of: kOldLevelThreeSeparator, with: kLevelThreeSeparator)
		.replacingOccurrences(of: kOldLevelFourSeparator, with: kLevelFourSeparator)
	}
    
    var opposite: String {
		switch self {
			case "[": return "]"
			case "]": return "["
			case "(": return ")"
			case ")": return "("
			case "{": return "}"
			case "}": return "{"
			case "<": return ">"
			case ">": return "<"
			default:  return self
		}
    }


    var escaped: String {
        var result = "\(self)"
        for character in "\\\"\'`" {
            let separator = "\(character)"
            let components = result.components(separatedBy: separator)
            result = components.joined(separator: "\\" + separator)
        }

        return result
    }
    
    
    var stripped: String {
        var before = self
        
        while before.starts(withAnyCharacterIn: kSpace) {
            before = before.substring(fromInclusive: 1) // strip extra space
        }
        
        while before.ends(withAnyCharacterIn: kSpace) {
            before = before.substring(toExclusive: before.length - 1) // strip trailing space
        }
        
        return before
    }

    
    /// remove underline from leading spaces
    var smartStripped: String {     //
        var altered = substring(fromInclusive: 4)
//        let lastIndex = altered.length - 1
//
//        if  altered[lastIndex] == "+" {
//            altered = altered.substring(toExclusive: lastIndex)
//        }

        altered = altered.stripped

        return altered
    }
    
    
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }


    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    
    static func from(_ ascii:  UInt32) -> String  { return String(UnicodeScalar(ascii)!) }
    func substring(fromInclusive: Int) -> String  { return String(self[index(at: fromInclusive)...]) }
    func substring(toExclusive:   Int) -> String  { return String(self[..<index(at: toExclusive)]) }
    func widthForFont  (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }


    func rect(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGRect {
        let bounds = rectWithFont(font)
        let xDelta = offset(using: font, for: iRange, atStart: atStart)
        
        return bounds.offsetBy(dx: xDelta, dy: 0.0)
    }

    
    func offset(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGFloat {
        let            end = iRange.lowerBound
        let     startRange = NSMakeRange(0, end)
        let      selection = substring(with: iRange)
        let startSelection = substring(with: startRange)
        let          width = selection     .sizeWithFont(font).width
        let     startWidth = startSelection.sizeWithFont(font).width
        
        return startWidth + (atStart ? 0.0 : width)    // move down, use right side of selection
    }


	var integerValue: Int? {
		if  let    value = Int(self) {
			return value
		}

		return nil
	}

    var floatValue: CGFloat? {
		if  let doubleValue = Double(self) {
			return CGFloat(doubleValue)
		}

		return nil
    }


    var color: ZColor? {
        if self != "" {
            let pairs = components(separatedBy: ",")
            var   red = 0.0
            var  blue = 0.0
            var green = 0.0

            for pair in pairs {
                let values = pair.components(separatedBy: kSeparator)
                let  value = Double(values[1])!
                let    key = values[0]

				switch key {
					case   "red":   red = value
					case  "blue":  blue = value
					case "green": green = value
					default:      break
				}
            }

            return ZColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
        }

        return nil
    }


    func index(at: Int) -> Index {
        var position = at

        repeat {
            if let index = index(startIndex, offsetBy: position, limitedBy: endIndex) {
                return index
            }

            position -= 1
        } while position > 0

        return startIndex
    }

	
	func starts(with: String) -> Bool {
		let start = substring(toExclusive: with.length)
		
		return with == start
	}
	

	func starts(withAnyCharacterIn: String) -> Bool {
		let start = substring(toExclusive: 1)
		
		return withAnyCharacterIn.contains(start)
	}


    func ends(withAnyCharacterIn: String) -> Bool {
        let end = substring(fromInclusive: length - 1)

        return withAnyCharacterIn.contains(end)
    }


    func stringBySmartly(appending: String) -> String {
        var before = self
        var  after = appending

        while after.starts(with: kSpace) {
            after = after.substring(fromInclusive: 1) // strip starting space
        }

        while before.ends(withAnyCharacterIn: kSpace) && after == "" {
            before = before.substring(toExclusive: before.length - 1) // strip trailing space
        }

        if !before.ends(withAnyCharacterIn: kSpace) && !after.starts(withAnyCharacterIn: kSpace) && !after.isEmpty {
            before = before + kSpace // add separator space when after is not empty
        }

        while before.starts(with: kSpace) {
            before = before.substring(fromInclusive: 1) // strip starting space
        }

        return before + after
    }


    func stringBySmartReplacing(_ range: NSRange, with replacement: String) -> String {
        let a = substring(toExclusive:   range.lowerBound)
        let b = replacement
        let c = substring(fromInclusive: range.upperBound)

        return a.stringBySmartly(appending: b.stringBySmartly(appending: c))
    }

    func substring(with range: NSRange) -> String {
        let iStart = index(at: range.lowerBound)
        let   iEnd = index(at: range.upperBound)

        return String(self[iStart ..< iEnd])
    }
    
    
    func location(of offset: CGFloat, using font: ZFont) -> Int {
        var location = 0
        var total = CGFloat(0.0)
        
        for (index, character) in enumerated() {
            let width = String(character).sizeWithFont(font).width
            let threshold = total + width / 2.0
            total += width

            if  threshold <= offset {
                location = index + 1
            }

            if  threshold >= offset {
                break
            }
        }

        return location
    }


    func character(at iOffset: Int) -> String {
        let index = self.index(startIndex, offsetBy: iOffset)

        return self[index].description
    }


    mutating func appendSpacesToLength(_ iLength: Int) {
        if 0 < iLength {
            while length < iLength {
                append(" ")
            }
        }
    }

    
    var isDashedLine: Bool {
        return contains(kHalfLineOfDashes)
    }
    

    var isLineWithTitle: Bool {
        let substrings = components(separatedBy: kHalfLineOfDashes)
        
        if  substrings.count == 3 {
            return substrings[1].count > 0 || substrings[2].count > 0
        }
        
        return false
    }

    
    func isLineTitle(enclosing range: NSRange) -> Bool {
        let a = substring(  toExclusive: range.lowerBound - 1)
        let b = substring(fromInclusive: range.upperBound + 1)

        return a == kHalfLineOfDashes && b == kHalfLineOfDashes
    }


    static func forZones(_ zones: [Zone]?) -> String {
        return zones?.apply()  { object -> (String?) in
            if  let zone  = object as? Zone {
                let name  = zone.decoratedName
                if  name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }


    static func forCKRecords(_ records: [CKRecord]?) -> String {
        return records?.apply() { object -> (String?) in
            if  let  record  = object as? CKRecord {
                let    name  = record.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }


    static func forReferences(_ references: [CKRecord.Reference]?, in databaseID: ZDatabaseID) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKRecord.Reference, let zone = gRemoteStorage.zRecords(for: databaseID)?.maybeZoneForReference(reference) {
                let    name  = zone.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }


    static func forOperationIDs (_ iIDs: [ZOperationID]?) -> String {
        return iIDs?.apply()  { object -> (String?) in
            if  let operation  = object as? ZOperationID {
                let name  = "\(operation)"
                if  name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }


    static func pluralized(_ iValue: Int, unit: String = "", plural: String = "s", followedBy: String = "") -> String {
        return iValue <= 0 ? "" : "\(iValue) \(unit)\(iValue == 1 ? "" : "\(plural)")\(followedBy)"
    }


    static func *(_ input: String, _ multiplier: Int) -> String {
        var  count = multiplier
        var output = ""

        while count > 0 {
            count  -= 1
            output += input
        }

        return output
    }


    static func character(at index: Int, for levelType: ZOutlineLevelType) -> String {
        if levelType == .roman {
            return toRoman(number: index + 1)
        } else if levelType == .number {
            return String(index + Int(levelType.level))
        } else {
            return String.from(levelType.asciiValue + UInt32(index))
        }
    }


    static func toRoman(number: Int) -> String {
        let romanValues = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        let arabicValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        var startingValue = number
        var romanValue = ""

        for (index, romanChar) in romanValues.enumerated() {
            let arabicValue = arabicValues[index]
            let ratio = startingValue / arabicValue

            if (ratio > 0) {
                for _ in 0 ..< ratio {
                    romanValue += romanChar
                }

                startingValue -= arabicValue * ratio
            }
        }

        return romanValue
    }
	
	
	func trimmed(by: Int = 1) -> String {
		let t = substring(toExclusive: self.length - by)
		return t.substring(fromInclusive: by)
	}
    
	
	func rangesMatching(_ iText: String?, needSpaces: Bool = true) -> [NSRange]? {
		if  let     t = iText?.lowercased() {
			let parts = lowercased().components(separatedBy: t)
			let count = parts.count - 1
			let match = " -,:.;"

			if  count > 0 {
				var   ranges = [NSRange] ()
				var location = 0
				
				for index in 0 ..< count {
					let  this = parts[index]
					let range = NSRange(location: location + this.length, length: t.length)
					location  = range.upperBound
					
					if  needSpaces,
						index + 1 < count {
						let next = parts[index + 1]

						if  (this.length > 0 && !this  .ends(withAnyCharacterIn: match)) ||
							(next.length > 0 && !next.starts(withAnyCharacterIn: match)) {
							continue
						}
					}

					ranges.append(range)
					
					break
				}
				
				return ranges
			}
		}
		
		return nil
	}

	func repeatOf(_ length: Int) -> String {
		var  count = length
		var result = ""

		while count > 0 {
			count -= 1

			result.append(self)
		}

		return result
	}

	func surround(with repeater: String) -> String {
		let inner = smallSurround(with: " ").smallSurround(with: repeater)
		let outer = repeater.repeatOf(count + 8)

		if  repeater == "" {
			return "\n\(inner)\n"
		} else {
			return "\n\(outer)\n\(inner)\n\(outer)\n"
		}
	}

	func smallSurround(with repeater: String) -> String {
		let small = repeater.repeatOf(2)

		return "\(small)\(self)\(small)"
	}

}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
    }
}


extension Date {
	
	var easyToReadDate: String {
		let f = DateFormatter()
		f.dateFormat = "MMM d, YYYY"
		
		return f.string(from: self)
	}
	
	var easyToReadTime: String {
		let f = DateFormatter()
		f.dateFormat = "h:mm a"
		
		return f.string(from: self)
	}

    func mid(to iEnd: Date?) -> Date? {
        let      end = iEnd ?? Date()
        let duration = timeIntervalSince(end) / 2.0
		
		if  duration > -1.0 {
			return nil
		}

        return addingTimeInterval(duration)
    }

}


extension ZGestureRecognizer {

    @objc var isShiftDown:   Bool { return false }
    @objc var isOptionDown:  Bool { return false }
    @objc var isCommandDown: Bool { return false }


    func cancel() {
        isEnabled = false
        isEnabled = true
    }
}


extension ZView {

    
    func clearGestures() {
        if recognizers != nil {
            for recognizer in recognizers! {
                removeGestureRecognizer(recognizer)
            }
        }
    }
    

    func addBorder(thickness: CGFloat, inset: CGFloat = 0.0, radius: CGFloat, color: CGColor) {
        zlayer.cornerRadius = radius
        zlayer.borderWidth  = thickness
        zlayer.borderColor  = color
    }


    func addBorderRelative(thickness: CGFloat, radius: CGFloat, color: CGColor) {
        let            size = self.bounds.size
        let radius: CGFloat = min(size.height, size.width) * radius

        self.addBorder(thickness: thickness, radius: radius, color: color)
    }


    func setAllSubviewsNeedDisplay() {
        if !gDeferRedraw {
            applyToAllSubviews { iView in
                iView.setNeedsDisplay()
            }
        }
    }


    func applyToAllSubviews(_ closure: ViewClosure) {
        closure(self)

        for view in subviews {
            view.applyToAllSubviews(closure)
        }
    }


    func applyToAllSuperviews(_ closure: ViewClosure) {
        closure(self)

        superview?.applyToAllSuperviews(closure)
    }

    
    func drawDots(surrounding rect: CGRect, count: Int, radius: Double, color: ZColor?, startQuadrant: Double = 0.0) {
        let  bigRadius = Double(rect.size.height) / 2.0
        var   dotCount = count
        var    aHollow = false
        var    bHollow = false
        var      scale = 0.0
        
        while dotCount > 100 {
            dotCount   = (dotCount + 5) / 10
            scale      = 1.0
            
            if  bHollow {
                aHollow = true
            } else {
                bHollow = true
            }
        }
        
        if  count > 0 {
            let     aCount = count % 10
            let     bCount = count / 10
            let fullCircle = Double.pi * 2.0
            let    aRadius = radius * (1.25 ** scale)
            let     center = rect.center
            
            let closure: IntBooleanClosure = { (iCount, isB) in
                let             oneSet = (isB ? aCount : bCount) == 0
                if  iCount             > 0 {
                    let         isEven = iCount % 2 == 0
                    let incrementAngle = fullCircle / (oneSet ? 1.0 : 2.0) / Double(iCount)
                    for index in 0 ... iCount - 1 {
                        let  increment = Double(index) + ((isEven && oneSet) ? 0.0 : 0.5)
                        let startAngle = fullCircle / 4.0 * (oneSet ? isEven ? 0.0 : 2.0 + startQuadrant : isB ? 1.0 : 3.0)
                        let      angle = startAngle + incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
                        let  dotRadius = CGFloat(bigRadius + aRadius * (isB ? 2.0 : 1.6))
                        let     offset = aRadius * (isB ? 2.1 : 1.13)
                        let  offCenter = CGPoint(x: center.x - CGFloat(offset), y: center.y - CGFloat(offset))
                        let          x = offCenter.x + (dotRadius * CGFloat(cos(angle)))
                        let          y = offCenter.y + (dotRadius * CGFloat(sin(angle)))
                        let   diameter = CGFloat((isB ? 4.0 : 2.5) * aRadius)
                        let   ovalRect = CGRect(x: x, y: y, width: diameter, height: diameter)
                        let       path = ZBezierPath(ovalIn: ovalRect)
                        path.lineWidth = CGFloat(gLineThickness)
                        path .flatness = 0.0001
                        
                        if  (!isB && aHollow) || (isB && bHollow) {
                            color?.setStroke()
                            path.stroke()
                        } else {
                            color?.setFill()
                            path.fill()
                        }
                    }
                }
            }
            
            closure(aCount, false)
            closure(bCount, true)
        }
    }
}


extension ZTextField {

    var       isEditingText:  Bool { return gIsEditingText }
    @objc var preferredFont: ZFont { return gWidgetFont }

    @objc func selectCharacter(in range: NSRange) {}
    @objc func alterCase(up: Bool) {}
    @objc func setup() {}
}
