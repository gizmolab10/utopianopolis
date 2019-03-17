//
//  ZClosures.h
//  Thoughtful
//
//  Created by Jonathan Sand on 3/9/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation;
import CloudKit


enum ZTraverseStatus: Int {
    case eContinue
    case eSkip
    case eStop
}


typealias Closure                 = ()                       -> (Void)
typealias IntClosure              = (Int)                    -> (Void)
typealias AnyClosure              = (Any?)                   -> (Void)
typealias DotClosure              = (ZoneDot)                -> (Void)
typealias ViewClosure             = (ZView)                  -> (Void)
typealias ZoneClosure             = (Zone)                   -> (Void)
typealias ZonesClosure            = ([Zone])                 -> (Void)
typealias ErrorClosure            = (Error)                  -> (Void)
typealias ArrayClosure            = ([Any]?)                 -> (Void)
typealias FloatClosure            = (CGFloat)                -> (Void)
typealias StringClosure           = (String)                 -> (Void)
typealias ObjectClosure           = (NSObject?)              -> (Void)
typealias SignalClosure           = (Any?,      ZSignalKind) -> (Void)
typealias RecordClosure           = (CKRecord?)              -> (Void)
typealias RecordsClosure          = ([CKRecord])             -> (Void)
typealias ClosureClosure          = (@escaping Closure)      -> (Void)
typealias BooleanClosure          = (Bool)                   -> (Void)
typealias CompareClosure          = (AnyObject, AnyObject)   -> (Bool)
typealias ToStringClosure         = ()                       -> (String?)
typealias ToObjectClosure         = ()                       -> (NSObject)
typealias ToBooleanClosure        = ()                       -> (Bool)
typealias ZoneMaybeClosure        = (Zone?)                  -> (Void)
typealias StringIntClosure        = (String,            Int) -> (Void)
typealias RecordIDsClosure        = ([CKRecord.ID])          -> (Void)
typealias ReferencesClosure       = ([CKRecord.Reference])   -> (Void)
typealias IntBooleanClosure       = (Int, Bool)              -> (Void)
typealias SignalKindClosure       = (ZSignalKind)            -> (Void)
typealias StateRecordClosure      = (ZRecordState,  ZRecord) -> (Void)
typealias AnyToStringClosure      = (Any)                    -> (String?)
typealias RecordErrorClosure      = (CKRecord?,      Error?) -> (Void)
typealias RecordsErrorClosure     = ([CKRecord],     Error?) -> (Void)
typealias ZoneToStatusClosure     = (Zone)                   -> (ZTraverseStatus)
typealias ZonesToZonesClosure     = ([Zone])                 -> ([Zone])
typealias StateCKRecordClosure    = (ZRecordState, CKRecord) -> (Void)
typealias ObjectToObjectClosure   = (NSObject)               -> (NSObject)
typealias ObjectToStringClosure   = (NSObject)               -> (String)
typealias StateRecordNameClosure  = (ZRecordState,   String) -> (Void)
typealias StringToBooleanClosure  = (String?)                -> (Bool)
typealias ZRecordToBooleanClosure = (ZRecord?)               -> (Bool)
typealias BooleanToBooleanClosure = (ObjCBool)               -> (ObjCBool)
typealias RecordsToRecordsClosure = ([CKRecord])             -> ([CKRecord])

