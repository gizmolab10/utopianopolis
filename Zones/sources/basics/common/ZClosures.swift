//
//  ZClosures.h
//  Seriously
//
//  Created by Jonathan Sand on 3/9/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import CoreGraphics;
import Foundation;
import CloudKit


enum ZTraverseStatus: Int {
    case eContinue
    case eSkip
    case eStop
}


typealias Closure                 = ()                       -> (Void)
typealias IntClosure              = (Int)                    -> (Void)
typealias URLClosure              = (URL)                    -> (Void)
typealias AnyClosure              = (Any?)                   -> (Void)
typealias DotClosure              = (ZoneDot)                -> (Void)
typealias ViewClosure             = (ZView)                  -> (Void)
typealias MenuClosure             = (ZMenuItem)              -> (Void)
typealias ZoneClosure             = (Zone)                   -> (Void)
typealias ZonesClosure            = (ZoneArray)              -> (Void)
typealias ErrorClosure            = (Error)                  -> (Void)
typealias ArrayClosure            = ([Any]?)                 -> (Void)
typealias FloatClosure            = (CGFloat)                -> (Void)
typealias TimerClosure            = (Timer?)                 -> (Void)
typealias ThrowsClosure           = ()               throws  -> (Void)
typealias StringClosure           = (String)                 -> (Void)
typealias ObjectClosure           = (NSObject?)              -> (Void)
typealias SignalClosure           = (Any?,      ZSignalKind) -> (Void)
typealias RecordClosure           = (CKRecord?)              -> (Void)
typealias RecordsClosure          = ([CKRecord])             -> (Void)
typealias BooleanClosure          = (Bool)                   -> (Void)
typealias CompareClosure          = (AnyObject,   AnyObject) -> (Bool)
typealias IntRectClosure          = (Int,            CGRect) -> (Void)
typealias ClosureClosure          = (@escaping Closure)      -> (Void)
typealias ThrowingClosure         = () throws                -> (Void)
typealias ToStringClosure         = ()                       -> (String?)
typealias ToObjectClosure         = ()                       -> (NSObject)
typealias ToBooleanClosure        = ()                       -> (Bool)
typealias ZoneMaybeClosure        = (Zone?)                  -> (Void)
typealias RecordIDsClosure        = ([CKRecord.ID])          -> (Void)
typealias StringIntClosure        = (String,            Int) -> (Void)
typealias IntBooleanClosure       = (Int,              Bool) -> (Void)
typealias ReferencesClosure       = ([CKRecord.Reference])   -> (Void)
typealias SignalKindClosure       = (ZSignalKind)            -> (Void)
typealias StateRecordClosure      = (ZRecordState,  ZRecord) -> (Void)
typealias AnyToStringClosure      = (Any)                    -> (String?)
typealias RecordErrorClosure      = (CKRecord?,      Error?) -> (Void)
typealias RecordsErrorClosure     = ([CKRecord],     Error?) -> (Void)
typealias ZoneToStatusClosure     = (Zone)                   -> (ZTraverseStatus)
typealias ZonesToZonesClosure     = (ZoneArray)              -> (ZoneArray)
typealias URLToBooleanClosure     = (URL)                    -> (Bool)
typealias StateCKRecordClosure    = (ZRecordState, CKRecord) -> (Void)
typealias ObjectToObjectClosure   = (NSObject)               -> (NSObject)
typealias ObjectToStringClosure   = (NSObject)               -> (String)
typealias StateRecordNameClosure  = (ZRecordState,   String) -> (Void)
typealias StringToBooleanClosure  = (String?)                -> (Bool)
typealias ZRecordToBooleanClosure = (ZRecord?)               -> (Bool)
typealias BooleanToBooleanClosure = (ObjCBool)               -> (ObjCBool)
typealias RecordsToRecordsClosure = ([CKRecord])             -> ([CKRecord])

