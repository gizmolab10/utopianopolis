//
//  XBClosures.h
//  Zones
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


typealias Closure                 = ()                                -> (Void)
typealias AnyClosure              = (Any?)                            -> (Void)
typealias ZoneClosure             = (Zone)                            -> (Void)
typealias ViewClosure             = (ZView)                           -> (Void)
typealias TimerClosure            = (Timer)                           -> (ObjCBool)
typealias StringClosure           = (String)                          -> (Void)
typealias ObjectClosure           = (NSObject?)                       -> (Void)
typealias SignalClosure           = (Any?,               ZSignalKind) -> (Void)
typealias RecordClosure           = (CKRecord?)                       -> (Void)
typealias RecordsClosure          = ([CKRecord])                      -> (Void)
typealias ClosureClosure          = (Closure)                         -> (Void)
typealias IntegerClosure          = (Int)                             -> (Void)
typealias BooleanClosure          = (Bool)                            -> (Void)
typealias ToStringClosure         = ()                                -> (String)
typealias ToObjectClosure         = ()                                -> (NSObject)
typealias ToBooleanClosure        = ()                                -> (Bool)
typealias ZoneMaybeClosure        = (Zone?)                           -> (Void)
typealias RecordIDsClosure        = ([CKRecordID])                    -> (Void)
typealias ReferencesClosure       = ([CKReference])                   -> (Void)
typealias StateRecordClosure      = (ZRecordState,           ZRecord) -> (Void)
typealias ZoneToStatusClosure     = (Zone)                            -> (ZTraverseStatus)
typealias DotToBooleanClosure     = (ZoneDot)                         -> (Bool)
typealias StringIntegerClosure    = (String,                     Int) -> (Void)
typealias StateCKRecordClosure    = (ZRecordState,          CKRecord) -> (Void)
typealias ModeAndSignalClosure    = (Any?, ZStorageMode, ZSignalKind) -> (Void)
typealias ObjectToObjectClosure   = (NSObject)                        -> (NSObject)
typealias ObjectToStringClosure   = (NSObject)                        -> (String)
typealias BooleanToBooleanClosure = (ObjCBool)                        -> (ObjCBool)
