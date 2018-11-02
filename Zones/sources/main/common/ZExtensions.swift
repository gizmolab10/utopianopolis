//
//  ZExtensions.swift
//  Zones
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


typealias ZStorageDictionary = [ZStorageType : NSObject]


extension NSObject {


    func            note(_ iMessage: Any?)                { } // logk(iMessage) }
    func     performance(_ iMessage: Any?)                { log(iMessage) }
    func textInputReport(_ iMessage: Any?)                { log(iMessage) }
    func             bam(_ iMessage: Any?)                { log("-------------------------------------------------------------------- " + (iMessage as? String ?? "")) }
    func  columnarReport(_ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(iFirst, iSecond) }


    func rawColumnarReport(_ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(kLogTabStop)
            log("\(prefix)\(iSecond ?? "")")
        }
    }


    func log(_ iMessage: Any?) {
        if  let   message = iMessage as? String, message != "" {
            print(message)
        }
    }


    func time(of title: String, _ closure: Closure) {
        let start = Date()

        closure()

        let duration = Date().timeIntervalSince(start)

        columnarReport(title, duration)
    }


    func blankScreenDebug() {
        if  let w = gEditorController?.editorRootWidget.bounds.size.width, w < 1.0 {
            bam("blank graph !!!!!!")
        }
    }


    func redrawAndSync(_ zone: Zone? = nil, _ onCompletion: Closure? = nil) {
        gControllersManager.syncToCloudAfterSignalFor(zone, regarding: .redraw, onCompletion: onCompletion)
    }


    func redrawSyncRedraw(_ zone: Zone? = nil) {
        redrawAndSync(zone) {
            self.signalFor(zone, regarding: .redraw)
        }
    }


    func signalFor(_ object: NSObject?, regarding: ZSignalKind) {
        gControllersManager.signalFor(object, regarding: regarding) {}
    }


    @discardableResult func detectWithMode(_ dbID: ZDatabaseID, block: ToBooleanClosure) -> Bool {
        gRemoteStoresManager.pushDatabaseID(dbID)

        let result = block()

        gRemoteStoresManager.popDatabaseID()
        
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


    func name(from iLink: String?) -> String? {
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
            let                 name = name(from: iLink) {
            var components: [String] = iLink!.components(separatedBy: kSeparator)
            let recordID: CKRecordID = CKRecordID(recordName: name)
            let ckRecord: CKRecord   = CKRecord(recordType: kZoneType, recordID: recordID)
            let        rawIdentifier = components[0]
            let   dbID: ZDatabaseID? = rawIdentifier == "" ? gDatabaseID : ZDatabaseID(rawValue: rawIdentifier)
            let              manager = gRemoteStoresManager.recordsManagerFor(dbID)
            let                 zone = manager?.zoneForCKRecord(ckRecord) ?? Zone(record: ckRecord, databaseID: dbID) // BAD DUMMY ?

            return zone
        }

        return nil
    }


    // MARK:- JSON
    // MARK:-


    func dictFromJSON(_ dict: [String : NSObject]) -> ZStorageDictionary {
        var                   result = ZStorageDictionary ()

        for (key, value) in dict {
            if  let       storageKey = ZStorageType(rawValue: key) {
                var        goodValue = value
                var       translated = false

                if  let string       = value as? String {
                    let parts        = string.components(separatedBy: kTimeInterval + ":")
                    if  parts.count > 1,
                        parts[0]    == "",
                        let interval = TimeInterval(parts[1]) {
                        goodValue    = Date(timeIntervalSinceReferenceDate: interval) as NSObject
                        translated   = true
                    }
                }

                if !translated {
                    if  let     subDict = value as? [String : NSObject] {
                        goodValue       = dictFromJSON(subDict) as NSObject
                    } else if let array = value as? [[String : NSObject]] {
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


    func jsonDictFrom(_ dict: ZStorageDictionary) -> [String : NSObject] {
        var deferals = ZStorageDictionary ()
        var   result = [String : NSObject] ()

        let closure = { (key: ZStorageType, value: Any) in
            var goodValue       = value
            if  let     subDict = value as? ZStorageDictionary {
                goodValue       = self.jsonDictFrom(subDict)
            } else if let  date = value as? Date {
                goodValue       = kTimeInterval + ":\(date.timeIntervalSinceReferenceDate)"
            } else if let array = value as? [ZStorageDictionary] {
                var jsonArray   = [[String : NSObject]] ()

                for subDict in array {
                    jsonArray.append(self.jsonDictFrom(subDict))
                }

                goodValue       = jsonArray
            }

            result[key.rawValue]   = (goodValue as! NSObject)
        }

        for (key, value) in dict {
            if [.children, .traits].contains(key) {
                deferals[key] = value
            } else {
                closure(key, value)
            }
        }

        for (key, value) in deferals {
            closure(key, value)
        }

        return result
    }

}


extension CKRecord {

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
        self.init(recordType: kZoneType, recordID: CKRecordID(recordName: name))
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


    func index(within iReferences: [CKRecordID]) -> Int? {
        var index: Int? = nil

        for (i, identifier) in iReferences.enumerated() {
            if  identifier == recordID {
                index = i

                break
            }
        }

        return index
    }


    func maybeMarkAsFetched(_ databaseID: ZDatabaseID?) {
        if  let dbID      = databaseID,
            creationDate != nil {
            let states    = [ZRecordState.notFetched]
            let manager   = gRemoteStoresManager.cloudManagerFor(dbID)
            if  manager.hasCKRecord(self, forAnyOf: states) {
                manager.clearCKRecords([self], for: states)
            }
        }
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

    var scalarDistance: CGFloat {
        return sqrt(width * width + height * height)
    }

}


extension CGRect {

    var center: CGPoint { return CGPoint(x: midX, y: midY) }
    var extent: CGPoint { return CGPoint(x: maxX, y: maxY) }


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

}


extension Array {


    func updateOrder() { updateOrdering(start: 0.0, end: 1.0) }


    func orderLimits() -> (start: Double, end: Double) {
        var start = 1.0
        var   end = 0.0

        for element in self {
            if  let   zone = element as? Zone {
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
        }

        return (start, end)
    }


    func sortedByReverseOrdering() -> Array {
        return sorted { (a, b) -> Bool in
            if  let zoneA = a as? Zone,
                let zoneB = b as? Zone {
                return zoneA.order > zoneB.order
            }

            return true
        }
    }


    func updateOrdering(start: Double, end: Double) {
        let increment = (end - start) / Double(self.count + 2)

        for (index, element) in self.enumerated() {
            if  let    child = element as? Zone {
                let newOrder = start + (increment * Double(index + 1))
                let    order = child.order

                if  order      != newOrder {
                    child.order = newOrder

                    child.maybeNeedSave()
                }
            }
        }
    }


    func apply(closure: AnyToStringClosure) -> String {
        var separator = ""
        var    string = ""

        for object in self {
            if let message = closure(object) {
                string.append("\(separator)\(message)")

                if  separator.length == 0 {
                    separator.appendSpacesToLength(kLogTabStop)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }

    
    func containsCompare(_ with: AnyObject, using: CompareClosure? = nil) -> Bool {
        if let compare = using {
            for item in self {
                if compare(item as AnyObject, with) {
                    return true
                }
            }
        }
        
        return false
    }
    

    mutating func appendUnique(contentsOf items: Array, compare: CompareClosure? = nil) {
        let array = self as NSArray
        
        for item in items {
            if  !array.contains(item),
                !containsCompare(item as AnyObject, using: compare) {
                append(item)
            }
        }
    }

}


extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var   asciiValue:  UInt32  { return asciiArray[0] }
    var          isDigit: Bool { return "0123456789.+-=*/".contains(self[startIndex]) }
    var   isAlphabetical: Bool { return "abcdefghijklmnopqrstuvwxyz".contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
    var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
    var           length: Int  { return unicodeScalars.count }


    var escaped: String {
        var result = "\(self)"
        for character in "\\\"\'`" {
            let separator = "\(character)"
            let components = result.components(separatedBy: separator)
            result = components.joined(separator: "\\" + separator)
        }

        return result
    }


    static func from(_ ascii: UInt32) -> String  { return String(UnicodeScalar(ascii)!) }
    func substring(from:         Int) -> String  { return substring(from: index(at: from)) }
    func substring(to:           Int) -> String  { return substring(to: index(at: to)) }
    func widthForFont (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }


    func heightForFont(_ font: ZFont, options: NSString.DrawingOptions = []) -> CGFloat { return sizeWithFont(font, options: options).height }


    func sizeWithFont(_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGSize {
        let   rect = CGSize(width: 1000000, height: 1000000)
        //let options: [NSStringDrawingOptions] = [.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics]
        let bounds = self.boundingRect(with: rect, options: options, attributes: [kCTFontAttributeName as String : font], context: nil)

        return bounds.size
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


    func ends(with: String) -> Bool {
        let    end = substring(from: length - 1)

        return end == with
    }


    func smartlyAppended(_ appending: String) -> String {
        var before = self
        var  after = appending

        while (before.ends(with: kSpace) || before == "") && after.starts(with: kSpace) {
            after = after.substring(from: 1)
        }

        while before.ends(with: kSpace) && after == "" {
            before = before.substring(to: before.length - 1)
        }

        return before + after
    }


    func stringBySmartReplacing(_ range: NSRange, with replacement: String) -> String {
        let a = substring(to:   range.lowerBound)
        let b = replacement
        let c = substring(from: range.upperBound)

        return a.smartlyAppended(b.smartlyAppended(c))
    }


    func substring(with range: NSRange) -> String {
        let iStart = index(at: range.lowerBound)
        let   iEnd = index(at: range.upperBound)

        return substring(with: iStart ..< iEnd)
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


    static func forReferences(_ references: [CKReference]?, in databaseID: ZDatabaseID) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(databaseID)?.maybeZoneForReference(reference) {
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



}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
    }
}


extension Date {

    func mid(to iEnd: Date?) -> Date {
        let      end = iEnd ?? Date()
        let duration = timeIntervalSince(end) / 2.0

        return addingTimeInterval(duration)
    }

}


extension ZColor {
    
    var converted: ZColor {
        let b = 1.0 - brightnessComponent

        return ZColor(calibratedHue: hueComponent, saturation: saturationComponent, brightness: b, alpha: alphaComponent)
    }
    
}


extension ZGestureRecognizer {

    var isShiftDown:   Bool { return false }
    var isOptionDown:  Bool { return false }
    var isCommandDown: Bool { return false }


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
        applyToAllSubviews { iView in
            iView.setNeedsDisplay()
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

}


extension ZTextField {

    var  isEditingText:  Bool { return false }
    var  preferredFont: ZFont { return gWidgetFont }

    func selectCharacter(in range: NSRange) {}
    func alterCase(up: Bool) {}
    func setup() {}
}


