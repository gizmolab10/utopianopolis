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
typealias BoolClosure             = (Bool)                   -> (Void)
typealias ViewClosure             = (ZView)                  -> (Void)
typealias MenuClosure             = (ZMenuItem)              -> (Void)
typealias ZoneClosure             = (Zone)                   -> (Void)
typealias ZonesClosure            = (ZoneArray)              -> (Void)
typealias ZFileClosure            = (ZFile)                  -> (Void)
typealias ErrorClosure            = (Error)                  -> (Void)
typealias ArrayClosure            = ([Any]?)                 -> (Void)
typealias FloatClosure            = (CGFloat)                -> (Void)
typealias TimerClosure            = (Timer?)                 -> (Void)
typealias IntAnyClosure           = (Int, Any?)              -> (Void)
typealias ThrowsClosure           = ()               throws  -> (Void)
typealias StringClosure           = (String)                 -> (Void)
typealias ObjectClosure           = (NSObject?)              -> (Void)
typealias SignalClosure           = (Any?,      ZSignalKind) -> (Void)
typealias RecordClosure           = (CKRecord?)              -> (Void)
typealias ZTraitClosure           = (ZTrait)                 -> (Void)
typealias ZTraitsClosure          = ([ZTrait])               -> (Void)
typealias RecordsClosure          = (CKRecordsArray)         -> (Void)
typealias ZRecordClosure          = (ZRecord?)               -> (Void)
typealias BooleanClosure          = (Bool)                   -> (Void)
typealias CompareClosure          = (AnyObject,   AnyObject) -> (Bool)
typealias IntRectClosure          = (Int,            CGRect) -> (Void)
typealias ClosureClosure          = (@escaping Closure)      -> (Void)
typealias ZRecordsClosure         = (ZRecordsArray)          -> (Void)
typealias ThrowingClosure         = () throws                -> (Void)
typealias ToStringClosure         = ()                       -> (String?)
typealias ToObjectClosure         = ()                       -> (NSObject)
typealias ToBooleanClosure        = ()                       -> (Bool)
typealias ZoneMaybeClosure        = (Zone?)                  -> (Void)
typealias AnyObjectClosure        = (AnyObject)              -> (Void)
typealias RecordIDsClosure        = (CKRecordIDsArray)       -> (Void)
typealias StringIntClosure        = (String,            Int) -> (Void)
typealias IntBooleanClosure       = (Int,              Bool) -> (Void)
typealias ReferencesClosure       = (CKReferencesArray)      -> (Void)
typealias SignalKindClosure       = (ZSignalKind)            -> (Void)
typealias SignalArrayClosure      = ([ZSignalKind])          -> (Void)
typealias StateRecordClosure      = (ZRecordState,  ZRecord) -> (Void)
typealias ThrowingIntClosure      = (Int)            throws  -> (Void)
typealias AnyToStringClosure      = (Any)                    -> (String?)
typealias StateStringClosure      = (ZRecordState,   String) -> (Bool)
typealias RecordErrorClosure      = (CKRecord?,      Error?) -> (Void)
typealias RecordsErrorClosure     = (CKRecordsArray, Error?) -> (Void)
typealias StringStringClosure     = (String?,       String?) -> (Void)
typealias ZoneToStatusClosure     = (Zone)                   -> (ZTraverseStatus)
typealias ZonesToZonesClosure     = (ZoneArray)              -> (ZoneArray)
typealias URLToBooleanClosure     = (URL)                    -> (Bool)
typealias StateCKRecordClosure    = (ZRecordState, CKRecord) -> (Void)
typealias ObjectToObjectClosure   = (NSObject)               -> (NSObject)
typealias ObjectToStringClosure   = (NSObject)               -> (String)
typealias StringToBooleanClosure  = (String?)                -> (Bool)
typealias ZRecordToBooleanClosure = (ZRecord?)               -> (Bool)
typealias BooleanToBooleanClosure = (ObjCBool)               -> (ObjCBool)
typealias RecordsToRecordsClosure = (CKRecordsArray)         -> (CKRecordsArray)

