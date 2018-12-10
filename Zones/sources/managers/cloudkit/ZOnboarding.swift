//
//  ZOnboarding.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gCloudAccountIsActive    : Bool { return gCloudAccountStatus == .active }
var gCloudAccountStatus      = ZCloudAccountStatus.begin
var recentCloudAccountStatus = gCloudAccountStatus
var gHasInternet             = true


class ZOnboarding : ZOperations {


    var           user : ZUser?
    var isMasterAuthor : Bool { return user?.access == .eMaster } // || macAddress == "c8:e0:eb:16:c9:9b" }
    var     macAddress : String?


    // MARK:- internals
    // MARK:-


    @objc func completeOnboarding(_ notification: Notification) {
        FOREGROUND(canBeDirect: true) {
            gBatches.batch(.bNewAppleID) { iResult in
                gFavorites.updateFavorites()
                gControllers.signalFor(nil, regarding: .eRelayout)
            }
        }
    }


    // MARK:- operations
    // MARK:-


    override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        switch operationID {
        case .oCheckAvailability: checkAvailability { onCompletion(true) }    // true means op is handled
        case .oFetchUserRecord:   fetchUserRecord   { onCompletion(true) }
        case .oFetchUserID:       fetchUserID       { onCompletion(true) }
        case .oUbiquity:          ubiquity          { onCompletion(true) }
        case .oObserveUbiquity:   observeUbiquity();  onCompletion(true)
        case .oMacAddress:        getMAC();           onCompletion(true)
        case .oInternet:          internet();         onCompletion(true)
        default:                                      onCompletion(false)     // false means op is not handled, so super should proceed
        }
    }


    func observeUbiquity() { gNotificationCenter.addObserver(self, selector: #selector(ZOnboarding.completeOnboarding), name: .NSUbiquityIdentityDidChange, object: nil) }
    func internet()        { gHasInternet = isConnectedToNetwork }


    func checkAvailability(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            if  iStatus            == .available {
                gCloudAccountStatus = .available

                //////////////////////////
                // ONBOARDING CONTINUES //
                //////////////////////////
            }

            onCompletion()
        }
    }


    func ubiquity(_ onCompletion: @escaping Closure) {
        if FileManager.default.ubiquityIdentityToken == nil {

            //////////////////////////
            // ONBOARDING CONTINUES //
            //////////////////////////

            checkCloudStatus()
        }

        onCompletion()
    }


    func fetchUserID(_ onCompletion: @escaping Closure) {
        if  gCloudAccountStatus != .available {
            onCompletion()
        } else {
            gContainer.fetchUserRecordID() { iRecordID, iError in
                gAlerts.alertError(iError, "failed to fetch user record id; reason unknown") { iHasError in
                    if !iHasError {

                        ////////////////////////////////////////////////
                        // persist for file read on subsequent launch //
                        //   also: for determining write permission   //
                        ////////////////////////////////////////////////

                        gUserRecordID = iRecordID?.recordName

                        //////////////////////////
                        // ONBOARDING CONTINUES //
                        //////////////////////////
                    }

                    onCompletion()
                }
            }
        }
    }


    func fetchUserRecord(_ onCompletion: @escaping Closure) {
        if  gCloudAccountStatus == .available,
            let     recordName  = gUserRecordID {
            let     ckRecordID  = CKRecord.ID(recordName: recordName)

            gEveryoneCloud?.assureRecordExists(withRecordID: ckRecordID, recordType: CKRecord.SystemType.userRecord) { (iUserRecord: CKRecord?) in
                if  let          record = iUserRecord {
                    let            user = ZUser(record: record, databaseID: gDatabaseID)
                    self          .user = user
                    gCloudAccountStatus = .active

                    //////////////////////////
                    // ONBOARDING CONTINUES //
                    //////////////////////////

                    if  user.authorID  == nil {
                        user.authorID   = UUID().uuidString

                        user.needSave()
                    }

                    gAuthorID           = user.authorID
                } else {
                    let            name = ckRecordID.recordName
                    gCloudAccountStatus = .none

                    ////////////////////////
                    //  ONBOARDING STOPS  //
                    ////////////////////////

                    // see: shouldPerform

                    print("alert: user record \(name) does not exist")
                }

                onCompletion()
            }
        } else {
            onCompletion()
        }
    }


    func getMAC() {
        if let intfIterator = findEthernetInterfaces() {
            if  let macAddressAsArray = getMACAddress(intfIterator) {
                let macAddressAsString = macAddressAsArray.map( { String(format:"%02x", $0) } )
                    .joined(separator: ":")
                macAddress = macAddressAsString
            }

            IOObjectRelease(intfIterator)
        }
    }


    func findEthernetInterfaces() -> io_iterator_t? {

        let matchingDict = IOServiceMatching("IOEthernetInterface") as NSMutableDictionary
        matchingDict["IOPropertyMatch"] = [ "IOPrimaryInterface" : true]

        var matchingServices : io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &matchingServices) != KERN_SUCCESS {
            return nil
        }

        return matchingServices
    }

    func getMACAddress(_ intfIterator : io_iterator_t) -> [UInt8]? {

        var macAddress : [UInt8]?

        var intfService = IOIteratorNext(intfIterator)
        while intfService != 0 {

            var controllerService : io_object_t = 0
            if IORegistryEntryGetParentEntry(intfService, "IOService", &controllerService) == KERN_SUCCESS {

                let dataUM = IORegistryEntryCreateCFProperty(controllerService, "IOMACAddress" as CFString, kCFAllocatorDefault, 0)
                if let data = dataUM?.takeRetainedValue() as? NSData {
                    macAddress = [0, 0, 0, 0, 0, 0]
                    data.getBytes(&macAddress!, length: macAddress!.count)
                }
                IOObjectRelease(controllerService)
            }

            IOObjectRelease(intfService)
            intfService = IOIteratorNext(intfIterator)
        }

        return macAddress
    }

}
