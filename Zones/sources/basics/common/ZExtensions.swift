//
//  ZExtensions.swift
//  Seriously
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

typealias                ZoneArray = [Zone]
typealias               CKRecordID = CKRecord.ID
typealias              ZOpIDsArray = [ZOperationID]
typealias              ZFilesArray = [ZFile]
typealias              ZTraitArray = [ZTrait]
typealias              CKReference = CKRecord.Reference
typealias             StringsArray = [String]
typealias            ZRecordsArray = [ZRecord]
typealias            ZObjectsArray = [NSObject]
typealias          ZoneWidgetArray = [ZoneWidget]
typealias          ZObjectIDsArray = [NSManagedObjectID]
typealias         CKRecordIDsArray = [CKRecordID]
typealias         ZTraitDictionary = [ZTraitType : ZTrait]
typealias         ZStoryboardSegue = NSStoryboardSegue
typealias         ZSignalKindArray = [ZSignalKind]
typealias        CKReferencesArray = [CKReference]
typealias        ZAssetsDictionary = [UUID : CKAsset]
typealias        ZTinyDotTypeArray = [[ZTinyDotType]]
typealias       ZRecordsDictionary = [ZDatabaseID: ZRecordsArray]
typealias       ZStorageDictionary = [ZStorageType : NSObject]
typealias    ZAttributesDictionary = [NSAttributedString.Key : Any]
typealias     ZStringAnyDictionary = [String :      Any]
typealias  ZStringObjectDictionary = [String : NSObject]
typealias  StringZRecordDictionary = [String :  ZRecord]
typealias StringZRecordsDictionary = [String :  ZRecordsArray]
let                   gApplication = ZApplication.shared

protocol ZGeneric {
	func setup()
}

func printFancy(_ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  let t = test, !t() { return }
	let fancy = (surround == nil) ? message : message.surround(with: surround!)
	FOREGROUND(canBeDirect: true) {
		print(fancy)
	}
}

func printDebug(_ mode: ZPrintMode, prefix: String = "  ", _ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  gPrintModes.contains(mode) {
		printFancy("\(mode): " + prefix + message, surround: surround, test)
	}
}

func gSeparatorAt(level: Int) -> String { return " ( \(level) ) " }

func gSignal(for object: Any? = nil, _ multiple: ZSignalKindArray, _ onCompletion: Closure? = nil) {
	gControllers.signalFor(object, multiple: multiple, onCompletion: onCompletion)
}

private var canUpdate = true

func gRelayoutMaps(for object: Any? = nil, _ onCompletion: Closure? = nil) {
	gSignal(for: object, [.sRelayout], onCompletion)
	gSmallMapController?.view.setNeedsDisplay()
	gMapController?     .view.setNeedsDisplay()
}

func gDeferRedraw(_ closure: Closure) {
	gDeferringRedraw = true

	closure()

	FOREGROUND(after: 0.4) {
		gDeferringRedraw = false   // in case closure doesn't set it
	}
}

func gDisablePush(_ closure: Closure) {
	gPushIsDisabled = true

	closure()

	gPushIsDisabled = false
}

func gCompareZones(_ a: AnyObject, _ b: AnyObject) -> Bool {
	if  let alpha = (a as? Zone)?.recordName,
		let  beta = (b as? Zone)?.recordName {
		return alpha == beta
	}

	return false
}

precedencegroup BooleanPrecedence { associativity: left }
infix operator ^^ : BooleanPrecedence
/**
Swift Logical XOR operator
```
true  ^^ true   // false
true  ^^ false  // true
false ^^ true   // true
false ^^ false  // false
```
- parameter lhs: First value.
- parameter rhs: Second value.
*/

func ^^(lhs: Bool, rhs: Bool) -> Bool {
	return lhs != rhs
}

extension NSObject {

	func                  noop()                                {}
    func           performance(_ iMessage: Any?)                { log(iMessage) }
    func                   bam(_ iMessage: Any?)                { log("-------------------------------------------------------------------- " + (iMessage as? String ?? kEmpty)) }
	func     printCurrentFocus()                                { gHere.widget?.printView() }
	func     printCurrentEssay()                                { gEssayView?.printView() }

	func columnarReport(mode: ZPrintMode = .dLog, _ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(mode: mode, iFirst, iSecond) }

	func rawColumnarReport(mode: ZPrintMode = .dLog, _ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(kLogTabStop)
            printDebug(mode, "\(prefix)\(iSecond ?? kEmpty)")
        }
    }

    func log(_ iMessage: Any?) {
        if  let   message = iMessage as? String, message != kEmpty {
            printDebug(.dLog, message)
        }
    }

	func debugTime(message: String, _ closure: Closure) {
		let start = Date()

		closure()

		let duration = Date().timeIntervalSince(start)

		printDebug(.dTime, duration.stringToTwoDecimals + kSpace + message)
	}

    func time(of title: String, _ closure: Closure) {
        let start = Date()

        closure()

        let duration = Date().timeIntervalSince(start)

        columnarReport(title, duration)
    }

    func blankScreenDebug() {
        if  let w = gMapController?.rootWidget?.bounds.size.width, w < 1.0 {
            bam("blank map !!!!!!")
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
        gUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            handler(iTarget)
        })
    }

	func showThesaurus(for string: String = kEmpty) {
		let url = NSURL(string: "https://www.thesaurus.com/browse/\(string)")
		url?.open()
	}

    func openBrowserForFocusWebsite() {
        "https://medium.com/@sand_74696/what-you-get-d565b064be7b".openAsURL()
    }

    func sendEmailBugReport() {
        "mailto:sand@gizmolab.com?subject=Regarding Seriously".openAsURL()

//		let service = NSSharingService(named: NSSharingService.Name.composeEmail)
//		service?.recipients = ["sand@gizmolab.com"]
//		service?.subject = "Reporting an error"
//		service?.perform(withItems: ["Something happened"])
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
                    let parts        = string.components(separatedBy: kTimeInterval + kColonSeparator)
                    if  parts.count > 1,
                        parts[0]    == kEmpty,
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

                result[storageKey]      = goodValue
            }
        }

        return result
    }
}

extension ZStorageDictionary {

	var mainDictionary : ZStorageDictionary? {
		for (key, value) in self {
			switch key {
				case .graph: return value as? ZStorageDictionary
				default:     break
			}
		}

		return self
	}

	var recordName : String? {
		for (key, value) in self {
			switch key {
				case .graph:      return (value as? ZStorageDictionary)?.recordName
				case .recordName: return  value as? String
				default:          break
			}
		}

		return nil
	}

	var jsonDict : ZStringObjectDictionary {
        var    last = ZStorageDictionary ()
        var  result = ZStringObjectDictionary ()

        let closure = { (key: ZStorageType, value: Any) in
            var goodValue        = value
            if  let      subDict = value as? ZStorageDictionary {
				goodValue        = subDict.jsonDict
            } else if let   date = value as? Date {
                goodValue        = kTimeInterval + ":\(date.timeIntervalSinceReferenceDate)"
            } else if let  array = value as? [ZStorageDictionary] {
                var jsonArray    = [ZStringObjectDictionary] ()

                for subDict in array {
                    jsonArray.append(subDict.jsonDict)
                }

                goodValue        = jsonArray
            }

            result[key.rawValue] = (goodValue as! NSObject)
        }

        for (iKey, value) in self {
			let key = (iKey != .essay) ? iKey : .note

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

extension Int {

	func within(_ range: ClosedRange<Int>) -> Bool {
		return range.contains(self)
	}

	func next(forward: Bool, max: Int) -> Int? {
		if  max <= 0                  { return nil }
		if self <= 0   &&  forward    { return max }
		if self >= max && !forward    { return 0 }

		let    next = self + (forward ? -1 : 1)
		if     next < 0 || next > max { return nil }
		return next
	}

}

extension Dictionary {

	var byteCount: Int { return data?.count ?? 0 }
	var string: String? { return data?.string }

	var data: Data? {
		do {
			let data = try JSONSerialization.data(withJSONObject:self, options: [])

			return data
		} catch {}

		return nil
	}

	subscript (i: Int) -> Any? {
		if  i < count {
			let k = Array(keys)

			return self[k[i]]
		}

		return nil
	}

}

extension URL {

	var originalImageName: String? { return CGImageSource.readFrom(self)?.originalImageName }

	func destination(imageType: CFString = kUTTypeImage) -> CGImageDestination? {
		return CGImageDestinationCreateWithURL(self as CFURL, imageType, 1, nil)
	}

	var imageProperties: [NSObject : AnyObject]? {
		if  let          source = CGImageSource.readFrom(self),
			let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as [NSObject : AnyObject]? {
			return imageProperties
		}

		return nil
	}

	var imageSize: CGSize? {
		if  let properties  = imageProperties {
			let pixelHeight = properties[kCGImagePropertyPixelHeight] as! Int
			let pixelWidth  = properties[kCGImagePropertyPixelWidth]  as! Int

			return CGSize(width: pixelWidth, height: pixelHeight)

		}

		return nil
	}

	func writeData(_ data: Data?) -> Bool {
		var success = false

		if  let d = data {
			do {
				try d.write(to: self, options: Data.WritingOptions.atomic)

				success = true
			} catch {
			}
		}

		return success
	}

	func fileExists() -> Bool { return FileManager.default.fileExists(atPath: path) }

}

extension CGImageSource {

	class func readFrom(_ url: URL) -> CGImageSource? { return CGImageSourceCreateWithURL(url as CFURL, nil) }
	var metadata: ZStringAnyDictionary? { return CGImageSourceCopyPropertiesAtIndex(self, 0, nil) as? ZStringAnyDictionary }
	var originalImageName: String? { return metadata?[kOrignalImageName] as? String }

}

extension CKAsset {

	var data       :   Data? { return FileManager.default.contents(atPath: fileURL.path) }
	var imageSize  : CGSize? { return fileURL.imageSize }
	var uuidString : String? { return value(forKeyPath: "_UUID") as? String }
	var length     :    Int? { return value(forKeyPath: "_size") as? Int }

}

extension CKRecord {

    var reference: CKReference { return CKReference(recordID: recordID, action: .none) }
	var entityName: String {
		switch recordType {
			case kUserRecordType: return kUserEntityName
			default:              return recordType
		}
	}

	var isOrphaned: Bool {
		var parentRecordName : String?
		var parentReference  = self[kpParent] as? CKReference

		if  parentReference == nil {
			if  let     link = self[kpZoneParentLink] as? String {
				parentRecordName = link.maybeRecordName // parent is in other db
			} else {
				parentReference  = self[kpOwner] as? CKReference
			}
		}

		if  let ref = parentReference {
			parentRecordName = ref.recordID.recordName
		}

		if  parentRecordName != nil {
			return gRemoteStorage.maybeZoneForRecordName(parentRecordName) == nil
		}

		return true
	}

	var storable: String {
		get {
			var pairs = StringsArray()
			let  keys = allKeys()

			for key in keys {
				if  let value = self[key] {
					let pair = "\(key)\(gSeparatorAt(level: 2))\(value)"

					pairs.append(pair)
				}
			}

			return pairs.joined(separator: gSeparatorAt(level: 1))
		}

		set {
			let pairs = newValue.componentsSeparatedAt(level: 1)

			for pair in pairs {
				let parts = pair.componentsSeparatedAt(level: 2)

				if  parts.count > 1 {
					let   key = parts[0]
					let value = parts[1]
					self[key] = value
				}
			}
		}
	}

    var isEmpty: Bool {
        for key in [kpZoneName, kpParent, kpZoneParentLink] {
            if  self[key] != nil {
                return false
            }
        }

        return true
    }

	var matchesFilterOptions: Bool {
		switch recordType {
			case kZoneType:
				let    isBookmark = self[kpZoneLink] != nil

				return isBookmark && gFilterOption.contains(.fBookmarks) || !isBookmark && gFilterOption.contains(.fIdeas)
			case kTraitType:
				return gFilterOption.contains(.fNotes)
			default: break
		}

		return true
	}

    var isBookmark: Bool {
        if  let    link = self[kpZoneLink] as? String {
            return link.contains(kColonSeparator)
        }

        return false
    }

	var traitType: String {
		var string = kEmpty

		if  let        type = self["type"] as? String,
			let       trait = ZTraitType(rawValue: type),
			let description = trait.description {
			string          = description + kSearchSeparator
		}

		return string
	}

    convenience init(for name: String) {
        self.init(recordType: kZoneType, recordID: CKRecordID(recordName: name))
    }

    func isDeleted(dbID: ZDatabaseID) -> Bool {
        return gRemoteStorage.cloud(for: dbID)?.manifest?.deletedRecordNames?.contains(recordID.recordName) ?? false
    }

    @discardableResult func copy(to iCopy: CKRecord?, properties: StringsArray) -> Bool {
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

}

extension ZTinyDotTypeArray {

	static func ideaTypes(_ count: Int) -> ZTinyDotTypeArray {
		var  types = ZTinyDotTypeArray()
		var  added = count

		while added > 0 {
			added  -= 1
			types.append([.eIdea])
		}

		return types
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

	static func ** (base: Double, power: Double) -> Double { return pow(base, power) }
	var    stringToTwoDecimals                    : String { return String(format: "%.02f", self) }
}

extension CGFloat {
	var    stringToTwoDecimals                    : String { return String(format: "%.02f", self) }
}

infix operator -- : AdditionPrecedence

extension CGPoint {

	var descriptionToTwoDecimals: String { return "(\(x.stringToTwoDecimals), \(y.stringToTwoDecimals))"}

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

	func offsetBy(_ delta: CGPoint) -> CGPoint {
		return CGPoint(x: x + delta.x, y: y + delta.y)
	}

	func offsetBy(_ delta: CGSize) -> CGPoint {
		return CGPoint(x: x + delta.width, y: y + delta.height)
	}

	func offsetBy(_ xOffset: CGFloat, _ yOffset: CGFloat) -> CGPoint {
		return CGPoint(x: x + xOffset, y: y + yOffset)
	}

	func intersectsTriangle(orientedUp: Bool, in iRect: CGRect) -> Bool {
		return ZBezierPath.trianglePath(orientedUp: orientedUp, in: iRect).contains(self)
	}

	func intersectsCircle(in iRect: CGRect) -> Bool {
		return ZBezierPath.circlePath(in: iRect).contains(self)
	}

	func intersectsCircle(orientedUp: Bool, in iRect: CGRect) -> Bool {
		let (path, _) = ZBezierPath.circlesPath(orientedUp: orientedUp, in: iRect)

		return path.contains(self)
	}

	var hypontenuse: CGFloat {
		return sqrt(x * x + y * y)
	}

	func rotate(by angle: Double) -> CGPoint {
		let r = hypontenuse

		return CGPoint(x: r * CGFloat(cos(angle)), y: r * CGFloat(sin(angle)))
	}

}

extension CGSize {

	public init(_ point: CGPoint) {
		self.init()

		width  = point.x
		height = point.y
	}

	static var big: CGSize {
		return CGSize(width: 1000000, height: 1000000)
	}

	var smallDimension: CGFloat {
		return min(abs(height), abs(width))
	}

    var length: CGFloat {
        return sqrt(width * width + height * height)
    }

	public static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
		var    size  = lhs
		size.height += rhs.height
		size.width  += rhs.width

		return size
	}

	public static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
		var    size  = lhs
		size.height -= rhs.height
		size.width  -= rhs.width

		return size
	}

	public static func - (lhs: CGSize, rhs: CGPoint) -> CGPoint {
		return CGPoint(CGPoint(lhs) - rhs)
	}

	func add(width: CGFloat, height: CGFloat) -> CGSize {
		return self + CGSize(width: width, height: height)
	}

	func absoluteDifferenceInDiagonals(relativeTo other: CGSize) -> CGFloat {
		return abs(length - other.length)
	}

	func fractionalScaleToFit(size: CGSize) -> CGFloat {
		var fraction = CGFloat(1.0)

		if  width < size.width {
			fraction = width / size.width
		}

		if  height < size.height {
			fraction = height * fraction / size.height
		}

		return fraction
	}

	func scaleToFit(size: CGSize) -> CGSize {
		let fraction = fractionalScaleToFit(size: size)

		return CGSize(width: width * fraction, height: height * fraction)
	}

	func isLargerThan(_ other: CGSize) -> Bool {
		return length > other.length
	}

	func multiplyBy(_ fraction: CGFloat) -> CGSize {
		return CGSize(width: width * fraction, height: height * fraction)
	}

	func multiplyBy(_ fraction: CGSize) -> CGSize {
		return CGSize(width: width * fraction.width, height: height * fraction.height)
	}

	func fraction(_ delta: CGSize) -> CGSize {
		CGSize(width: (width - delta.width) / width, height: (height - delta.height) / height)
	}

	func fractionPreservingRatio(_ delta: CGSize) -> CGSize {
		let ratio = (width - delta.width) / width

		return CGSize(width: ratio, height: ratio)
	}

	func insetBy(_ x: CGFloat, _ y: CGFloat) -> CGSize {
		return CGSize(width: width - (x * 2.0), height: height - (y * 2.0))
	}

	func offsetBy(_ x: CGFloat, _ y: CGFloat) -> CGSize {
		return CGSize(width: width + x, height: height + y)
	}

	func offsetBy(_ delta: CGSize) -> CGSize {
		return CGSize(width: width + delta.width, height: height + delta.height)
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

	var centerTop:        CGPoint { return CGPoint(x: midX, y: minY) }
	var centerLeft:       CGPoint { return CGPoint(x: minX, y: midY) }
	var centerRight:      CGPoint { return CGPoint(x: maxX, y: midY) }
	var center:           CGPoint { return CGPoint(x: midX, y: midY) }
	var centerBottom:     CGPoint { return CGPoint(x: midX, y: maxY) }
	var bottomRight:      CGPoint { return CGPoint(x: maxX, y: minY) }
	var topLeft:          CGPoint { return CGPoint(x: minX, y: maxY) }
	var extent:           CGPoint { return CGPoint(x: maxX, y: maxY) }
	var minimumDimension: CGFloat { return min(size.height, size.width) }

	var cornerPoints: [ZDirection : CGPoint] {
		var           result = [ZDirection : CGPoint]()
		result[.topLeft]     = topLeft
		result[.topRight]    = extent
		result[.bottomLeft]  = origin
		result[.bottomRight] = bottomRight

		return result
	}

	var selectionPoints: [ZDirection : CGPoint] {
		var           result = cornerPoints
		result[.top]         = centerTop
		result[.left]        = centerLeft
		result[.right]       = centerRight
		result[.bottom]      = centerBottom

		return result
	}

    public init(start: CGPoint, extent: CGPoint) {
        self.init()

		origin = start
        size   = extent - origin

        if  size .width < 0 {
            size .width = -size.width
            origin   .x = extent.x
        }

        if  size.height < 0 {
            size.height = -size.height
            origin   .y = extent.y
        }
    }

    func indices(within iBounds: CGRect, radix: Int) -> IndexSet {
        let c = center
        var set = IndexSet()

        set.insert(Int(c.x))

        return set
    }

    func offsetBy(fractionX: CGFloat = 0.0, fractionY: CGFloat = 0.0) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY
        
        return offsetBy(dx:dX, dy:dY)
    }

	func insetBy(fractionX: CGFloat = 0.0, fractionY: CGFloat = 0.0) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY

        return insetBy(dx: dX, dy: dY)
    }

	func insetEquallyBy(fraction: CGFloat) -> CGRect {
		return insetBy(fractionX: fraction, fractionY: fraction)
	}

	func insetEquallyBy(_ inset: CGFloat) -> CGRect {
		return insetBy(dx: inset, dy: inset)
	}

	func offsetEquallyBy(_ offset: CGFloat) -> CGRect {
		return offsetBy(dx: offset, dy: offset)
	}

	func centeredEquallyAround(_ center: CGPoint, diameter: CGFloat) -> CGRect {
		return CGRect(origin: center, size: CGSize.zero).insetEquallyBy(-diameter / 2.0)
	}

	func centeredRect(diameter: CGFloat) -> CGRect {
		return centeredEquallyAround(center, diameter: diameter)
	}

	func twoDotsVertically(fractionalDiameter: CGFloat) -> (CGRect, CGRect) {
		let a = CGRect(origin: centerBottom, size: .zero)
		let b = CGRect(origin: centerTop,    size: .zero)
		let d = height * fractionalDiameter

		return (a.centeredRect(diameter: d), b.centeredRect(diameter: d))
	}

	func twoDotsHorizontally(fractionalDiameter: CGFloat) -> (CGRect, CGRect) {
		let a = CGRect(origin: centerLeft,  size: .zero)
		let b = CGRect(origin: centerRight, size: .zero)
		let d = width * fractionalDiameter

		return (a.centeredRect(diameter: d), b.centeredRect(diameter: d))
	}

	func centeredHorizontalLine(thick: CGFloat) -> CGRect {
		let y = center.y - (thick / 2.0)

		return CGRect(origin: CGPoint(x: minX, y: y), size: CGSize(width: maxX - minX, height: thick))
	}

	func centeredVerticalLine(thick: CGFloat) -> CGRect {
		let x = center.x - (thick / 2.0)

		return CGRect(origin: CGPoint(x: x, y: minY), size: CGSize(width: thick, height: maxY - minY))
	}

	var squareCentered: CGRect {
		let length = size.smallDimension
		let origin = CGPoint(x: minX + (size.width - length) / 2.0, y: minY + (size.height - length) / 2.0)

		return CGRect(origin: origin, size: CGSize(width: length, height: length))
	}

	func intersectsOval(within other: CGRect) -> Bool {
		let center =  other.center
		let radius = (other.height + other.width) / 4.0
		let deltaX = center.x - max(minX, min(center.x, maxX))
		let deltaY = center.y - max(minY, min(center.y, maxY))
		let  delta = radius - sqrt(deltaX * deltaX + deltaY * deltaY)

		return delta > 0
	}

	func drawColoredRect(_ color: ZColor, radius: CGFloat = 8.0, thickness: CGFloat = 0.5) {
		let       path = ZBezierPath(roundedRect: self, xRadius: radius, yRadius: radius)
		path.lineWidth = thickness

		color.setStroke()
		path.stroke()
	}

	func drawColoredOval(_ color: ZColor, filled: Bool = false) {
		let oval = ZBezierPath(ovalIn: self)

		color.setStroke()
		oval.stroke()

		if  filled {
			color.setFill()
			oval.fill()
		}
	}

}

extension ZBezierPath {

	static func drawTriangle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
		let path = trianglePath(orientedUp: orientedUp, in: iRect)

		path.draw(thickness: thickness)
	}

	static func trianglePath(orientedUp: Bool, in iRect: CGRect) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendTriangle(orientedUp: orientedUp, in: iRect)

		return path
	}

	static func drawCircle(in iRect: CGRect, thickness: CGFloat) {
		let path = circlePath(in: iRect)

		path.draw(thickness: thickness)
	}

	static func circlePath(in iRect: CGRect) -> ZBezierPath {
		return ZBezierPath(ovalIn: iRect)
	}

	static func drawCircles(in iRect: CGRect, thickness: CGFloat, orientedUp: Bool) -> CGRect {
		let (path, rect) = circlesPath(orientedUp: orientedUp, in: iRect)

		path.draw(thickness: thickness)

		return rect
	}

	static func circlesPath(orientedUp: Bool, in iRect: CGRect) -> (ZBezierPath, CGRect) {
		let path = ZBezierPath()
		let rect = path.appendCircles(orientedUp: orientedUp, in: iRect)

		return (path, rect)
	}

	static func bloatedTrianglePath(in iRect: CGRect, aimedRight: Bool) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendBloatedTriangle(in: iRect, aimedRight: aimedRight)

		return path
	}

	func addDashes() {
		let pattern: [CGFloat] = [3.0, 3.0]

		setLineDash(pattern, count: 2, phase: 3.0)
	}

	func appendTriangle(orientedUp: Bool, in iRect: CGRect) {
		let yStart = orientedUp ? iRect.minY : iRect.maxY
		let   yEnd = orientedUp ? iRect.maxY : iRect.minY
		let    tip = CGPoint(x: iRect.midX, y: yStart)
		let   left = CGPoint(x: iRect.minX, y: yEnd)
		let  right = CGPoint(x: iRect.maxX, y: yEnd)

		move(to: tip)
		line(to: left)
		line(to: right)
		line(to: tip)
	}

	func appendCircles(orientedUp: Bool, in iRect: CGRect) -> CGRect {
		let   rect = iRect.offsetBy(fractionX: 0.0, fractionY: orientedUp ? 0.1 : -0.1)
		var    top = rect.insetBy(fractionX: 0.0, fractionY: 0.375)  // shrink to one-fifth size
		let middle = top.offsetBy(dx: 0.0, dy: top.midY - rect.midY)
		let bottom = top.offsetBy(dx: 0.0, dy: top.maxY - rect.maxY) // move to bottom
		top        = top.offsetBy(dx: 0.0, dy: top.minY - rect.minY) // move to top

		appendOval(in: top)
		appendOval(in: middle)
		appendOval(in: bottom)

		return orientedUp ? top : bottom
	}

	func draw(thickness: CGFloat) {
		lineWidth = thickness

		stroke()
	}

	func appendBloatedTriangle(in iRect: CGRect, aimedRight: Bool) {
		let      center = iRect.center
		let  insetRatio = 0.35
		let      radius = Double(iRect.width) * insetRatio
		let  startAngle = aimedRight ? 0.0 : Double.pi
		let    bigAngle = Double.pi /  3.0 // one sixth of a circle
		let  smallAngle = Double.pi / 15.0 // one thirtieth
		let innerVector = CGPoint(x: radius,       y: 0.0)
		let outerVector = CGPoint(x: radius * 1.5, y: 0.0)
		var  controlOne = CGPoint.zero
		var  controlTwo = CGPoint.zero
		var       point = CGPoint.zero
		var       index = 0.0

		func rotatePoints() {
			let   angle = index * bigAngle + startAngle
			let   other = angle - bigAngle
			let     one = other - smallAngle
			let     two = other + smallAngle
			point       = innerVector.rotate(by: angle).offsetBy(center)
			controlOne  = outerVector.rotate(by:   one).offsetBy(center)
			controlTwo  = outerVector.rotate(by:   two).offsetBy(center)
			index      += 2.0
		}

		rotatePoints()
		move(to: point)
		rotatePoints()
		curve(to: point, controlPoint1: controlOne, controlPoint2: controlTwo)
		rotatePoints()
		curve(to: point, controlPoint1: controlOne, controlPoint2: controlTwo)
		rotatePoints()
		curve(to: point, controlPoint1: controlOne, controlPoint2: controlTwo)
	}

	func appendCircle(at center: CGPoint, radius: CGFloat) {
		let rect = CGRect(origin: center, size: CGSize.zero).insetBy(dx: -radius, dy: -radius)

		appendOval(in: rect)
	}

}

extension Array {

	func apply(closure: AnyObjectClosure) {
		for element in self {
			closure(element as AnyObject)
		}
	}

	func applyBoolean(closure: AnyObjectToBooleanClosure) -> Bool {
		var result = false
		for element in self {
			if  closure(element as AnyObject) {
				result = true
				break
			}
		}
		return result
	}

    func applyIntoString(closure: AnyToStringClosure) -> String {
        var separator = kEmpty
        var    string = kEmpty

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

	func next(from: Int, forward: Bool) -> Element? {
		if  let index = from.next(forward: forward, max: count - 1) {
			return self[index]
		}

		return nil
	}

	func intersects(_ other: Array) -> Bool {
		return intersection(other).count > 0
	}

	func intersection(_ other: Array) -> Array {
		var result = Array()

		apply { another in
			other.apply { yetAnother in
				if  yetAnother.isEqual(to: another) {
					result.append(another as! Element)
				}
			}
		}

		return result
	}

	func containsAnyOf(_ other: Any?) -> Bool {
		return (other == nil) ? false : containsCompare(with: other) { (item, another) in
			return item === another
		}
	}

    func containsCompare(with other: Any?, using: CompareClosure? = nil) -> Bool {
        if  let compare = using,
			let to = other as AnyObject? {
            for item in self {
                if  compare(item as AnyObject, to) {
                    return true     // true means has a match
                }
            }
        }
        
        return false    // false means has no match
    }

	mutating func insertUnique(item: Any?, at index: Int = 0, compare: CompareClosure? = nil) {
		if  let e = item as? Element,
			!containsCompare(with: item, using: compare) {
			insert(e, at: index)
		}
	}

	@discardableResult mutating func appendUnique(item: Any?, compare: CompareClosure? = nil) -> Bool {
		if  let e = item as? Element,
			!containsCompare(with: item, using: compare) {
			append(e)
			return true
		}
		return false
	}

	mutating func appendUnique(contentsOf items: Array, compare: CompareClosure? = nil) {
		let existing = self as NSArray

		for item in items {
			if  !existing.contains(item),
				!containsCompare(with: item as AnyObject, using: compare) {
				append(item)
			}
		}
	}

	mutating func appendUniqueAndRemoveDuplicates(contentsOf items: Array, compare: CompareClosure? = nil) {
		let    existing = self as NSArray
		var iDuplicates = Array<Int>()

		for (index, item) in items.enumerated() {
			if  existing.contains(item) || containsCompare(with: item as AnyObject, using: compare) {
				iDuplicates.insert(index, at: 0)
			} else {
				append(item)
			}
		}

		for index in iDuplicates {
			if  count > index {
				remove(at: index)
			}
		}
	}

}

extension CKReferencesArray {

	func containsReference(_ reference: CKReference) -> Bool {
		return containsCompare(with: reference) { (item, another) in
			return item.recordID.recordName == another.recordID.recordName
		}
	}

	func asZones(in dbID: ZDatabaseID) -> ZoneArray {
		return map { ckReference -> Zone in
			return Zone.uniqueZone(recordName: ckReference.recordID.recordName, in: dbID)
		}
	}

	var asRecordNames: StringsArray {
		return map { ckReference -> String in
			return ckReference.recordID.recordName
		}
	}

}

extension ZRecordsArray {

	static func fromObjectIDs(_ ids: ZObjectIDsArray, in context: NSManagedObjectContext) -> ZRecordsArray {
		return ids.map { context.object(with: $0) as? ZRecord }.filter { $0 != nil }.map { $0! }
	}

	var recordNames: StringsArray {
		var  names = StringsArray()

		for zRecord in self {
			if  let name = zRecord.recordName {
				names.append(name)
			}
		}

		return names
	}

	func createStorageArray(from dbID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false, allowEach: ZRecordToBooleanClosure? = nil) throws -> [ZStorageDictionary]? {
		if  count > 0 {
			var result = [ZStorageDictionary] ()

			for zRecord in self {
				if  zRecord.recordName == nil {
					printDebug(.dFile, "no record name: \(zRecord)")
				} else if (allowEach == nil || allowEach!(zRecord)),
						  let dict = try zRecord.createStorageDictionary(for: dbID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {

					if  dict.count != 0 {
						result.append(dict)
					} else {
						printDebug(.dFile, "empty storage dictionary: \(zRecord)")

						if  let dict2 = try zRecord.createStorageDictionary(for: dbID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
							print("gotcha \(dict2.count)")
						}
					}
				}
			}

			if  result.count > 0 {
				return result
			}
		}

		return nil
	}

	func appending(_ records: ZRecordsArray?) -> ZRecordsArray {
		if  let  more = records {
			var union = ZRecordsArray()
			union.append(contentsOf: self)
			for other in more {
				union.appendUnique(item: other) // calls the method below this one, for stricter uniqueness
			}

			return union
		}

		return self
	}

	@discardableResult mutating func appendUnique(item: ZRecord) -> Bool {
		return appendUnique(item: item) { (a, b) -> (Bool) in
			if  let    aName  = (a as? ZRecord)?.recordName,
				let    bName  = (b as? ZRecord)?.recordName {
				return aName ==  bName
			}

			return false
		}
	}

	func containsMatch(to other: AnyObject) -> Bool {
		return containsCompare(with: other) { (a, b) in
			if  let    aName  = (a as? ZRecord)?.recordName,
				let    bName  = (b as? ZRecord)?.recordName {
				return aName ==  bName
			}

			return false
		}
	}

}

extension NSRange {

	var center: Int { return (lowerBound + upperBound) / 2 }

	func insetBy   (_ inset:  Int)    -> NSRange { return NSRange(location:  inset + location, length: length - (inset * 2)) }
	func offsetBy  (_ offset: Int)    -> NSRange { return NSRange(location: offset + location, length: length) }
	func contains  (_ other: NSRange) ->    Bool { return inclusiveIntersection(other) == other }
	func intersects(_ other: NSRange) ->    Bool { return intersection(other) != nil }

	func extendedBy(_ increment: Int) -> NSRange {
		if  increment > 0 {
			return NSRange(location: location, length: increment + length)
		} else {
			return NSRange(location: increment + location, length: length - increment)
		}
	}

	func inclusiveIntersection(_ other: NSRange) -> NSRange? {
		if  let    i = intersection(other) {
			return i
		}

		if  upperBound == other.location {
			return NSRange(location: other.location, length: 0)
		}

		if  other.upperBound == location {
			return NSRange(location: location, length: 0)
		}

		return nil
	}

}

extension NSCursor {

	class func fourArrows() -> NSCursor? {
		let     length = 20
		let halfLength = length / 2
		let       size = CGSize(width: length, height: length)
		let    hotSpot = CGPoint(x: halfLength, y: halfLength)
		if  let  image = kFourArrowsImage?.resize(size) {
			return NSCursor(image: image, hotSpot: hotSpot)
		}
		return nil
	}

}

extension NSTextTab {

	var string: String {
		return kAlignment + gSeparatorAt(level: 6) + "\(alignment.rawValue)" + gSeparatorAt(level: 5) + kLocation + gSeparatorAt(level: 6) + "\(location)"
	}

	convenience init(string: String) {
		var location: CGFloat = 0.0
		var alignment = NSTextAlignment.natural

		let parts = string.componentsSeparatedAt(level: 5)

		for part in parts {
			let subparts = part.componentsSeparatedAt(level: 6)
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
		var result = kAlignment + gSeparatorAt(level: 3) + "\(alignment.rawValue)"
		let  lists = textLists

		if  let stops = tabStops {
			result.append(gSeparatorAt(level: 2) + kStops)

			for stop in stops {
				result.append(gSeparatorAt(level: 3) + stop.string)
			}
		}

		result.append(gSeparatorAt(level: 2) + kLists)

		for list in lists {
			let  format = list.markerFormat.rawValue
			let options = "\(list.listOptions.rawValue)"

			result.append(gSeparatorAt(level: 3) + format)
			result.append(gSeparatorAt(level: 4) + options)
		}

		return result
	}

	convenience init(string: String) {
		self.init()

		let parts = string.componentsSeparatedAt(level: 2)

		for part in parts {
			let subparts = part.componentsSeparatedAt(level: 3)
			let    count = subparts.count
			var    index = 1

			if  count > 1 {
				switch subparts[0] {
					case kAlignment:
						if  let     raw = subparts[1].integerValue,
							let       a = NSTextAlignment(rawValue: raw) {
							alignment   = a
						}
					case kLists:
						var       lists = [NSTextList]()
						while     index < count {
							let subpart = subparts[index]
							let subsubs = subpart.componentsSeparatedAt(level: 4)
							let  format = NSTextList.MarkerFormat(subsubs[0])
							let options = 0 // Int(subsubs[1]) ?? 0
							index      += 1

							lists.append(NSTextList(markerFormat: format, options: options))
						}

						textLists = lists
					case kStops:
						var       stops = [NSTextTab]()
						while     index < count {
							let subpart = subparts[index]
							index      += 1

							stops.append(NSTextTab(string: subpart))
						}

						tabStops       = stops
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
		var    result = kEmpty
		var separator = kEmpty

		for (name, attribute) in fontAttributes {
			result.append(separator + name.rawValue + gSeparatorAt(level: 3) + "\(attribute)")
			separator = gSeparatorAt(level: 2)
		}

		return result
	}

	convenience init(string: String) {
		let parts = string.modern.componentsSeparatedAt(level: 2)
		var dict  = [NSFontDescriptor.AttributeName : Any]()

		for part in parts {
			let subparts   = part.componentsSeparatedAt(level: 3)
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

struct ZRangedAttachment {
	let range: NSRange
	let attachment: NSTextAttachment

	func glyphRect(for textStorage: NSTextStorage?, margin: CGFloat) -> CGRect? {
		if  let          managers = textStorage?.layoutManagers, managers.count > 0 {
			let     layoutManager = managers[0] as NSLayoutManager
			let        containers = layoutManager.textContainers
			if  containers .count > 0 {
				let textContainer = containers[0]
				var    glyphRange = NSRange()

				layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)

				let          rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).offsetBy(dx: margin, dy: margin)

				return rect
			}
		}

		return nil
	}

}

extension NSMutableAttributedString {

	var allKeys: [NSAttributedString.Key] { return [.font, .link, .attachment, .paragraphStyle, .foregroundColor, .backgroundColor] }

	var linkRanges: [NSRange] {
		let range = NSRange(location: 0, length: length)
		var found = [NSRange]()

		enumerateAttribute(.link, in: range, options: []) { (item, inRange, flag) in
			if  inRange.length < 100 {
				found.append(inRange)
			}
		}

		return found
	}

	var rangedAttachments: [ZRangedAttachment] {
		let range = NSRange(location: 0, length: length)
		var found = [ZRangedAttachment]()

		enumerateAttribute(.attachment, in: range, options: .reverse) { (item, inRange, flag) in
			if  let attach = item as? NSTextAttachment {
				let append = ZRangedAttachment(range: inRange, attachment: attach)

				found.append(append)
			}
		}

		return found
	}

	var imageFileNames: StringsArray {
		var names = StringsArray()

		for rangedAttach in rangedAttachments {
			if  let name = rangedAttach.attachment.fileWrapper?.preferredFilename {
				names.append(name)
			}
		}

		return names
	}

	var attachmentCells: [NSTextAttachmentCell] {
		var array = [NSTextAttachmentCell] ()

		for rangedAttach in rangedAttachments {
			if  let  cell = rangedAttach.attachment.attachmentCell as? NSTextAttachmentCell {
				array.append(cell)
			}
		}

		return array
	}

	var attachedImages: [ZImage] {
		let array: [ZImage?] = attachmentCells.map { $0.image }

		var result = [ZImage]()

		for item in array {
			if  let image = item {
				result.append(image)
			}
		}

		return result
	}

	var attributesAsString: String {
		get { return attributeStrings.joined(separator: gSeparatorAt(level: 1)) }
		set { attributeStrings = newValue.componentsSeparatedAt(level: 1) }
	}

	var attributeStrings: StringsArray {
		get {
			var result = StringsArray()
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

						if  let attach = value as? NSTextAttachment,
							let   file = attach.fileWrapper { // check if file actually exists
							string     = file.preferredFilename
						}

						if  let append = string as? String {
							result.append("\(inRange.location)" + gSeparatorAt(level: 4) + "\(inRange.length)" + gSeparatorAt(level: 4) + key.rawValue + gSeparatorAt(level: 4) + append)
						}
					}
				}
			}

			return result
		}

		set {
			for string in newValue {
				let      parts = string.componentsSeparatedAt(level: 4)
				if       parts.count > 3,
					let  start = parts[0].integerValue,
					let  count = parts[1].integerValue {
					let    raw = parts[2]
					let string = parts[3]
					let    key = NSAttributedString.Key(rawValue: raw)
					let  range = NSRange(location: start, length: count)
					var attribute: Any?

					switch key {
						case .link:            attribute =                                    string
						case .font:            attribute = ZFont 		   		     (string: string)
						case .attachment:      attribute = gCurrentTrait?.textAttachment(for: string)
						case .foregroundColor,
							 .backgroundColor: attribute = ZColor				     (string: string)
						case .paragraphStyle:  attribute = NSMutableParagraphStyle   (string: string)
						default:    		   break
					}

					if  let value = attribute {
						printDebug(.dNotes, "add attribute over \(range) for \(raw): \(value)")

						addAttribute(key, value: value, range: range)
					}
				}
			}
		}
	}

	// ONLY called during save note (in set note text)
	// side-effect for a freshly dropped image:
	// it creates and returns an additional asset

	func assets(for trait: ZTraitAssets) -> [CKAsset]? {
		var array = [CKAsset]()
		let     i = attachedImages // grab from text attachment cells

		for (index, name) in imageFileNames.enumerated() {
			if  index < i.count {
				let image = i[index]
				if  let a = trait.assetFromImage(image, for: name) {
					array.append(a)
				}
			}
		}

		return array.count == 0 ? nil : array
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

extension NSTextAttachmentCell {

	var frame: CGRect {
		return CGRect(origin: attachment?.bounds.origin ?? CGPoint.zero, size: cellSize())
	}
}

extension ZImage {

	func resize(_ newSize: CGSize) -> NSImage {
		let newImage = NSImage(size: newSize)
		newImage.lockFocus()
		draw(in: CGRect(origin: .zero, size: newSize), from: CGRect(origin: .zero, size: size), operation: .sourceOver, fraction: CGFloat(1))
		newImage.unlockFocus()
		return newImage
	}

	var invertedImage: ZImage? {
		if  let   tiffData = tiffRepresentation,
			let     bitMap = NSBitmapImageRep(data: tiffData) {
			let beginImage = CIImage(bitmapImageRep: bitMap)

			if  let filter = CIFilter(name: "CIColorInvert") {
				filter.setValue(beginImage, forKey: kCIInputImageKey)

				if  let filtered = filter.outputImage {
					let imageRep = NSCIImageRep(ciImage: filtered)
					let newImage = NSImage(size: imageRep.size)

					newImage.addRepresentation(imageRep)

					return newImage
				}
			}
		}

		return nil
	}

}

extension NSTextAttachment {

	var cellImage: ZImage? {
		get {
			if  let cell = attachmentCell as? NSTextAttachmentCell {
				return cell.image
			}

			return nil
		}

		set {
			if  let   cell = attachmentCell as? NSTextAttachmentCell {
				cell.image = newValue
			}
		}
	}

	func refreshImage() {
		// how?
	}

}

extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var   asciiValue:  UInt32  { return asciiArray[0] }
    var           length: Int  { return unicodeScalars.count }
	var         isHyphen: Bool { return self == "-" }
    var          isDigit: Bool { return "0123456789.+-=*/".contains(self[startIndex]) }
    var   isAlphabetical: Bool { return "abcdefghijklmnopqrstuvwxyz".contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
	var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
	var  containsNonTabs: Bool { return filter{ $0 != kTab.first}.count != 0 }
    var       isOpposite: Bool { return "]}>)".contains(self) }
	var     isDashedLine: Bool { return contains(kHalfLineOfDashes) }
	var      isValidLink: Bool { return components != nil }
	var  components: StringsArray? { return components(separatedBy: kColonSeparator) }

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
            result = components.joined(separator: kBackSlash + separator)
        }

        return result
    }

    var spacesStripped: String {
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

        altered = altered.spacesStripped

        return altered
    }

	var modern: String {
		return replacingOccurrences(of: kLevelOneSeparator,   with: gSeparatorAt(level: 1))
			.replacingOccurrences  (of: kLevelTwoSeparator,   with: gSeparatorAt(level: 2))
			.replacingOccurrences  (of: kLevelThreeSeparator, with: gSeparatorAt(level: 3))
			.replacingOccurrences  (of: kLevelFourSeparator,  with: gSeparatorAt(level: 4))
	}

	var searchable: String {
		return lowercased()
			.replacingEachCharacter(in: ",;@!(){}\\\"",              with: kEmpty)
			.replacingEachCharacter(in: ".:_-='?/\r\n",              with: kSpace)
			.replacingEachString   (in: ["%2f", "%3a", "   ", "  "], with: kSpace)
	}

	var unCamelcased: String {
		guard self.count > 0 else { return self }

		var newString: String = kEmpty
		let         uppercase = CharacterSet.uppercaseLetters
		let             first = unicodeScalars.first!

		newString.append(Character(first))

		for scalar in unicodeScalars.dropFirst() {
			if  uppercase.contains(scalar) {
				newString.append(kSpace)
			}
			let character = Character(scalar)
			newString.append(character)
		}

		return newString.lowercased()
	}

	// MARK:- bookmarks
	// MARK:-

	var maybeRecordName: String? {
		if  let   parts  = components, parts.count > 1 {
			let    name  = parts[2]
			return name != kEmpty ? name : kRootName // by design: empty component means root
		}

		return nil
	}

	var maybeDatabaseID: ZDatabaseID? {
		if  let   parts  = components {
			let    dbID  = parts[0]
			return dbID == kEmpty ? nil : ZDatabaseID(rawValue: dbID)
		}

		return nil
	}

	var maybeZone: Zone? {
		if  self             != kEmpty,
			let          name = maybeRecordName,
			let         parts = components {
			let rawIdentifier = parts[0]
			let          dbID = rawIdentifier == kEmpty ? gDatabaseID : ZDatabaseID(rawValue: rawIdentifier)
			let      zRecords = gRemoteStorage.zRecords(for: dbID)
			let          zone = zRecords?.maybeZoneForRecordName(name)

			return zone
		}

		return nil
	}

	func componentsSeparatedAt(level: Int) -> StringsArray {
		return components(separatedBy: gSeparatorAt(level: level))
	}

	func replacingEachCharacter(in matchAgainst: String, with: String) -> String {
		var        result = self
		for character in matchAgainst {
			let separator = String(character)
			result        = result.replacingOccurrences(of: separator, with: with)
		}

		return result
	}

	func replacingEachString(in matchAgainst: StringsArray, with: String) -> String {
		var result = self
		for string in matchAgainst {
			result = result.replacingOccurrences(of: string, with: with)
		}

		return result
	}

	var asBundleResource: String? {
		var    parts = components(separatedBy: kDotSeparator)
		let     last = parts.removeLast()
		let resource = parts.joined(separator: kDotSeparator)

		return Bundle.main.path(forResource: resource, ofType: last)
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

	static func pluralized(_ iValue: Int, unit: String = kEmpty, plural: String = "s", followedBy: String = kEmpty) -> String { return iValue <= 0 ? kEmpty : "\(iValue) \(unit)\(iValue == 1 ? kEmpty : "\(plural)")\(followedBy)" }
    static func from(_ ascii:  UInt32) -> String  { return String(UnicodeScalar(ascii)!) }
    func substring(fromInclusive: Int) -> String  { return String(self[index(at: fromInclusive)...]) }
    func substring(toExclusive:   Int) -> String  { return String(self[..<index(at: toExclusive)]) }
    func widthForFont  (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }

    func rect(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGRect {
		let within = substring(with: iRange)
		let bounds = within.rectWithFont(font)
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

	var doubleValue: Double? {
		return Double(self)
	}

    var floatValue: CGFloat? {
		if  let d = doubleValue {
			return CGFloat(d)
		}

		return nil
    }

    var color: ZColor? {
		if  self == kEmpty {
			return nil
		} else {
            let pairs = components(separatedBy: kCommaSeparator)
            var   red = 0.0
            var  blue = 0.0
            var green = 0.0

            for pair in pairs {
                let values = pair.components(separatedBy: kColonSeparator)
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

        while before.ends(withAnyCharacterIn: kSpace) && after == kEmpty {
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
				append(kSpace)
			}
		}
	}

    func appendingSpacesToLength(_ iLength: Int) -> String {
		var appending = self

		appending.appendSpacesToLength(iLength)

		return appending
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

	static func forZones(_ zones: ZoneArray?) -> String {
		return zones?.applyIntoString()  { object -> (String?) in
			if  let zone  = object as? Zone {
				let name  = zone.decoratedName
				if  name != kEmpty {
					return name
				}
			}

			return nil
		} ?? kEmpty
	}

    static func forOperationIDs (_ iIDs: ZOpIDsArray?) -> String {
        return iIDs?.applyIntoString()  { object -> (String?) in
            if  let operation  = object as? ZOperationID {
                let name  = "\(operation)"
                if  name != kEmpty {
                    return name
                }
            }

            return nil
            } ?? kEmpty
    }

    static func *(_ input: String, _ multiplier: Int) -> String {
        var  count = multiplier
        var output = kEmpty

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
        let   romanValues = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        let  arabicValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        var startingValue = number
        var    romanValue = kEmpty

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

	func rangesMatching(_ iText: String?, ignoreRange: NSRange, seekForward: Bool = true, needSpaces: Bool = true) -> [NSRange]? {
		return rangesMatching(iText, needSpaces: needSpaces)
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
		var result = kEmpty

		while count > 0 {
			count -= 1

			result.append(self)
		}

		return result
	}

	func surround(with repeater: String) -> String {
		let inner = smallSurround(with: kSpace).smallSurround(with: repeater)
		let outer = repeater.repeatOf(count + 8)

		if  repeater == kEmpty {
			return "\n\(inner)\n"
		} else {
			return "\n\(outer)\n\(inner)\n\(outer)\n"
		}
	}

	func smallSurround(with repeater: String, repeating: Int = 2) -> String {
		let small = repeater.repeatOf(repeating)

		return "\(small)\(self)\(small)"
	}

}

extension NSPredicate {

	func and(_ predicate: NSPredicate) -> NSPredicate {
		return NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self])
	}

}

extension Character {

	var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
    }

}

extension Data {

	var checksum : Int {
		return map { Int($0) }.reduce(0, +)
	}

	var string: String? {
		do {
			if  let s = try JSONSerialization.jsonObject(with: self, options: .mutableLeaves) as? String {
				return s
			}
		} catch {}

		return nil
	}

	func storeFor(_ key: String) {
		let query = [
			kSecValueData   as String : self,
			kSecAttrAccount as String : key,
			kSecClass       as String : kSecClassGenericPassword as String
		] as CFDictionary

		SecItemDelete(query)
		SecItemAdd   (query, nil)
	}

	static func loadFor(_ key: String) -> Data? {
		let query = [
			kSecClass       as String : kSecClassGenericPassword as String,
			kSecAttrAccount as String : key,
			kSecReturnData  as String : kCFBooleanTrue,
			kSecMatchLimit  as String : kSecMatchLimitOne
		] as CFDictionary

		var dataTypeRef : AnyObject? = nil

		if  SecItemCopyMatching(query as CFDictionary, &dataTypeRef) == noErr {
			return dataTypeRef as! Data?
		}

		return nil
	}

}

extension ZColor {

	static func + (left: ZColor, right: ZColor?) -> ZColor {
		if right == nil { return left }

		var (rLeft,  gLeft,  bLeft,  aLeft)  = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
		var (rRight, gRight, bRight, aRight) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))

		left  .getRed(&rLeft,  green: &gLeft,  blue: &bLeft,  alpha: &aLeft)
		right!.getRed(&rRight, green: &gRight, blue: &bRight, alpha: &aRight)

		return ZColor(red: (rLeft + rRight) / 2, green: (gLeft + gRight) / 2, blue: (bLeft + bRight) / 2, alpha: (aLeft + aRight) / 2)
	}

}

extension Date {

	func easyToReadDateFrom(_ format: String) -> String {
		let f = DateFormatter()
		f.dateFormat = format

		return f.string(from: self)
	}

	var easyToReadDateTime: String { return easyToReadDateFrom("h:mm a MMM d, YYYY") }
	var easyToReadDate:     String { return easyToReadDateFrom("MMM d, YYYY") }
	var easyToReadTime:     String { return easyToReadDateFrom("h:mm a") }

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
	var       isDone:        Bool { return [.ended, .cancelled, .failed, .possible].contains(state) }

    func cancel() {
        isEnabled = false // Apple says "when changed to NO the gesture recognizer will be cancelled [and] will not receive events"
        isEnabled = true
    }

}

extension ZView {

	@objc var size: CGSize { return bounds.size }

	var currentMouseLocation: CGPoint? {
		if  let windowLocation = window?.convertPoint(fromScreen: ZEvent.mouseLocation) {
			return convert(windowLocation, from: nil)
		}

		return nil
	}

	var simpleToolID : ZSimpleToolID? {
		let           item = self as NSUserInterfaceItemIdentification
		if  let identifier = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
			let     itemID = ZSimpleToolID(rawValue: identifier) {
			return  itemID
		}

		return nil
	}

	var linkButtonType : ZLinkButtonType? {
		let        item = self as NSUserInterfaceItemIdentification
		if  let  itemID = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
			let    type = ZLinkButtonType(rawValue: itemID) {
			return type
		}

		return nil
	}

	var modeButtonType : ZModeButtonType? {
		get {
			let        item = self as NSUserInterfaceItemIdentification
			if  let  itemID = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
				let    type = ZModeButtonType(rawValue: itemID) {
				return type
			}

			return nil
		}

		set {
			if  let  value = newValue?.rawValue {
				identifier = convertToUserInterfaceItemIdentifier(value)
			}
		}
	}

	var helpMode : ZHelpMode? {
		get {
			let        item = self as NSUserInterfaceItemIdentification
			if  let  itemID = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
				let    mode = ZHelpMode(rawValue: itemID) {
				return mode
			}

			return nil
		}

		set {
			if  let  value = newValue?.rawValue {
				identifier = convertToUserInterfaceItemIdentifier(value)
			}
		}
	}

	func removeAllSubviews() {
		for view in subviews {
			view.removeFromSuperview()
		}
	}

    func clearGestures() {
        if  recognizers != nil {
            for recognizer in recognizers! {
                removeGestureRecognizer(recognizer)
            }
        }
    }

	func printConstraints() {
		var result = StringsArray()

		result.append("\(identifier?.rawValue ?? "dunno") ")

		for constraint in constraints {
			result.append("\(constraint)")
		}

		print(result.joined(separator: kReturn))
	}

	func drawColoredRect(_ rect: CGRect, _ color: ZColor, thickness: CGFloat = 0.5) {
		let     radius = CGFloat(8.0)
		let       path = ZBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
		path.lineWidth = thickness

		color.setStroke()
		path.stroke()
	}

	func drawColoredOval(_ rect: CGRect, _ color: ZColor, filled: Bool = false) {
		let oval = ZBezierPath(ovalIn: rect)

		color.setStroke()
		oval.stroke()

		if  filled {
			color.setFill()
			oval.fill()
		}
	}

    func drawBorder(thickness: CGFloat, inset: CGFloat = 0.0, radius: CGFloat, color: CGColor) {
        zlayer.cornerRadius = radius
        zlayer.borderWidth  = thickness
        zlayer.borderColor  = color
    }

    func setAllSubviewsNeedDisplay() {
        if !gDeferringRedraw {
            applyToAllSubviews { view in
                view.setNeedsDisplay()
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

	func locationFromEvent(_ event: ZEvent) -> CGPoint {
		return convert(event.locationInWindow, from: nil)
	}

	func rectFromEvent(_ event: ZEvent) -> CGRect {
		return convert(CGRect(origin: event.locationInWindow, size: .zero), from: nil)
	}

	func analyze(_ object: AnyObject?) -> (Bool, Bool, Bool, Bool, Bool) {
		return (false, true, false, false, false)
	}

	func addTracking(for rect: CGRect, clearFirst: Bool = true) {
		if  clearFirst {
			for area in trackingAreas {
				removeTrackingArea(area)
			}
		}

		let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate]
		let tracker = NSTrackingArea(rect:rect, options: options, owner:self, userInfo: nil)

		addTrackingArea(tracker)
	}

}

extension ZPseudoView {

	func drawTinyDots(surrounding rect: CGRect, count: Int?, radius: Double, color: ZColor?, countMax: Int = 10, clockwise: Bool = false, onEach: IntRectClosure? = nil) {
		if  var       dotCount = count {
			var      fatHollow = false
			var     tinyHollow = false
			var      tinyIsFat = false
			var          scale = 1.0

			while     dotCount > (countMax *  countMax) {
				dotCount       = (dotCount + (countMax / 2)) / countMax    // round to closest
				scale          = 1.25

				if  fatHollow {
					tinyHollow = true
				} else {
					tinyIsFat  = true
					fatHollow  = true
				}
			}

			if  dotCount       > 0 {
				let  tinyCount = dotCount % countMax
				let   fatCount = dotCount / countMax
				let fullCircle = Double.pi * 2.0

				let drawDots: IntBooleanClosure = { (iCount, isFat) in
					let             oneSet = (isFat ? tinyCount : fatCount) == 0
					let           isHollow = (isFat && fatHollow) || (!isFat && tinyHollow)

					if  iCount             > 0 {
						let         isEven = iCount % 2 == 0
						let incrementAngle = fullCircle / (oneSet ? 1.0 : 2.0) / Double(-iCount)
						let     startAngle = fullCircle / 4.0 * ((clockwise ? 0.0 : 1.0) * (oneSet ? (isEven ? 0.0 : 2.0) : isFat ? 1.0 : 3.0)) + (oneSet ? 0.0 : Double.pi)

						for index in 0 ... iCount - 1 {
							let  increment = Double(index) + ((clockwise || (isEven && oneSet)) ? 0.0 : 0.5)
							let      angle = startAngle + incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
							let (ideaFocus, asIdea, asEssay) = (false, true, false)

							// notes are ALWAYS big (fat ones are bigger) and ALWAYS hollow (surround idea dots)
							// ideas are ALWAYS tiny and SOMETIMES fat (if over ten) and SOMETIMES hollow (if over hundered)
							//
							// so, three booleans: isFat, isHollow, forNote
							//
							// everything should always goes out more (regardless of no notes)

							func drawDot(isFocus: Bool) {
								let          asFat = isFat || tinyIsFat
								let    offsetRatio = asFat ? 2.1 : 1.28
								let       fatRatio = isFat ? 2.0 : 1.6
								let       dotRatio = asFat ? 4.0 : 2.5

								let   scaledRadius = radius * scale
								let  necklaceDelta = scaledRadius * 2.0 * 1.5
								let      dotRadius = scaledRadius * fatRatio
								let     rectRadius = Double(rect.size.height) / 2.0
								let necklaceRadius = CGFloat(rectRadius + necklaceDelta)
								let    dotDiameter = CGFloat(dotRadius  * dotRatio)
								let         offset = CGFloat(dotRadius  * offsetRatio)

								let     rectCenter = rect.center
								let         center = CGPoint(x: rectCenter.x - offset, y: rectCenter.y - offset)
								let              x = center.x + (necklaceRadius * CGFloat(cos(angle)))
								let              y = center.y + (necklaceRadius * CGFloat(sin(angle)))

								let       ovalRect = CGRect(x: x, y: y, width: dotDiameter, height: dotDiameter)
								let           path = ZBezierPath(ovalIn: ovalRect)
								path    .lineWidth = CGFloat(gLineThickness * (asEssay ? 7.0 : 3.0))
								path     .flatness = 0.0001

								if  isHollow {
									color?.setStroke()
									path.stroke()
								} else {
									color?.setFill()
									path.fill()
								}

								onEach?(index, ovalRect)
							}

							if  asIdea {
								drawDot(isFocus: ideaFocus)
							}
						}
					}
				}

				drawDots( fatCount, true)  // isFat = true
				drawDots(tinyCount, false)
			}
		}
	}

}

extension ZTextField {

    var       isEditingText:  Bool { return gIsEditIdeaMode }
    @objc var preferredFont: ZFont { return gWidgetFont }

    @objc func selectCharacter(in range: NSRange) {}
    @objc func alterCase(up: Bool) {}
}
