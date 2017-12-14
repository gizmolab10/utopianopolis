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


typealias ZStorageDict = [String : NSObject]
typealias       ZModes = [ZStorageMode]


extension NSObject {


    func            note(_ iMessage: Any?)                { } // report(iMessage) }
    func     performance(_ iMessage: Any?)                { log(iMessage) }
    func textInputReport(_ iMessage: Any?)                { log(iMessage) }
    func  columnarReport(_ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(iFirst, iSecond) }
    func      debugCheck()                                { gTravelManager.debugCheck() }


    func rawColumnarReport(_ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(gLogTabStop)
            log("\(prefix)\(iSecond ?? "")")
        }
    }


    func log(_ iMessage: Any?) {
        if  let message = iMessage as? String, message != "" {
            print(message)
        }
    }


    func redrawAndSync(_ iZone: Zone? = nil, _ onCompletion: Closure? = nil) {
        gControllersManager.syncToCloudAndSignalFor(iZone, regarding: .redraw, onCompletion: onCompletion)
    }


    func redrawAndSyncAndRedraw(_ iZone: Zone? = nil) {
        redrawAndSync(iZone) {
            self.signalFor(iZone, regarding: .redraw)
        }
    }


    func signalFor(_ object: NSObject?, regarding: ZSignalKind) {
        gControllersManager.signalFor(object, regarding: regarding, onCompletion: nil)
    }


    @discardableResult func detectWithMode(_ mode: ZStorageMode, block: ToBooleanClosure) -> Bool {
        gRemoteStoresManager.pushMode(mode)

        let result = block()

        gRemoteStoresManager.popMode()
        
        return result
    }


    func invokeUnderStorageMode(_ mode: ZStorageMode?, block: Closure) {
        if  mode != nil && mode != gStorageMode {
            detectWithMode(mode!) { block(); return false }
        } else {
            block()
        }
    }


    func UNDO<TargetType : AnyObject>(_ target: TargetType, handler: @escaping (TargetType) -> Swift.Void) {
        gUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            handler(iTarget)
        })
    }


    func openBrowserForFocusWebsite() {
        "https://medium.com/@sand_74696/what-you-get-d565b064be7b".openAsURL()
    }


    // MARK:- bookmarks
    // MARK:-


    func name(from iLink: String?) -> String? {
        if let link = iLink {
            var components = link.components(separatedBy: gSeparatorKey)

            if  components.count < 3 {
                return nil
            }

            return components[2] == "" ? "root" : components[2]
        }

        return nil
    }


    func zoneFrom(_ link: String?) -> Zone? {
        if  link == nil || link == "" {
            return nil
        }

        var components: [String] = link!.components(separatedBy: gSeparatorKey)

        if  components.count < 3 {
            return nil
        }

        let           name: String = components[2] == "" ? "root" : components[2]
        let identifier: CKRecordID = CKRecordID(recordName: name)
        let     ckRecord: CKRecord = CKRecord(recordType: gZoneTypeKey, recordID: identifier)
        let                rawMode = components[0]
        let    mode: ZStorageMode? = rawMode == "" ? gStorageMode : ZStorageMode(rawValue: rawMode)
        let                manager = gRemoteStoresManager.recordsManagerFor(mode)
        let                   zone = manager?.zoneForCKRecord(ckRecord) ?? Zone(record: ckRecord, storageMode: mode)

        return zone
    }
}


extension CKRecord {


    var decoratedName: String {
        if recordType       != gZoneTypeKey {
            return recordID.recordName
        } else if let   name = self[gZoneNameKey] as? String {
            let    separator = " "
            var       suffix = ""

            if let link  = self["zoneLink"] as? String {
                if link == gNullLink || link == "not a link" {
                    suffix.append("-")
                } else {
                    suffix.append("L")
                }
            }

            if  let fetchable = self["zoneCount"] as? Int, fetchable > 1 {
                if  suffix != "" {
                    suffix.append(separator)
                }

                suffix.append("\(fetchable)")
            }

            if  suffix != "" {
                suffix  = "  (" + suffix + ")"
            }

            return name.appending(suffix)
        }

        return ""
    }


    convenience init(for name: String) {
        self.init(recordType: gZoneTypeKey, recordID: CKRecordID(recordName: name))
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

}


infix operator -- : AdditionPrecedence


extension CGPoint {

    public init(_ size: CGSize) {
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
}


extension Array {

    func updateOrdering() {
        updateOrdering(start: 0.0, end: 1.0)
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

                    child.needSave()
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
                    separator.appendSpacesToLength(gLogTabStop)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }
}


extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var          isDigit: Bool { return "0123456789.+-=*/".contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
    var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
    var           length: Int  { return unicodeScalars.count }

    func substring(from:         Int) -> String  { return substring(from: index(at: from)) }
    func substring(to:           Int) -> String  { return substring(to: index(at: to)) }
    func heightForFont(_ font: ZFont) -> CGFloat { return sizeWithFont(font).height }
    func widthForFont (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }


    var color: ZColor? {
        if self != "" {
            let pairs = components(separatedBy: ",")
            var   red = 0.0
            var  blue = 0.0
            var green = 0.0

            for pair in pairs {
                let values = pair.components(separatedBy: gSeparatorKey)
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


    func sizeWithFont(_ font: ZFont) -> CGSize {
        let   rect = CGSize(width: 1000000, height: 1000000)
        let bounds = self.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [kCTFontAttributeName as String : font], context: nil)

        return bounds.size
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


    func substring(with r: Range<Int>) -> String {
        let startIndex = index(at: r.lowerBound)
        let   endIndex = index(at: r.upperBound)

        return substring(with: startIndex..<endIndex)
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
}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
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


    func addBorder(thickness: CGFloat, radius: CGFloat, color: CGColor) {
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


    func thinStroke(_ path: ZBezierPath?) {
        if  path != nil {
            path!.lineWidth = CGFloat(gLineThickness)

            path!.stroke()
        }
    }
}


extension ZTextField {

    var  isEditingText:  Bool { return false }
    var  preferredFont: ZFont { return gWidgetFont }

    func selectCharacter(in range: NSRange) {}
    func captureText(force: Bool = false) {}
    func alterCase(up: Bool) {}
    func updateText() {}
    func setup() {}
}


