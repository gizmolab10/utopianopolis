//
//  SessionManager.h
//  thynconealpha
//
//  Created by Jonathan Sand on 12/1/14.
//  Copyright (c) 2014 Jonathan Sand. All rights reserved.
//

#import "BuildControls.h"

#ifdef SESSION_MANAGER_SUPPORTS_USERS
#import "User.h"
#endif

#import "Enums.h"
#import "Signal.h"


#define kStagingServerDomain            @"stage"
#define kDevelopmentServerDomain        @"dev"
#define kPerformanceServerDomain        @"perf"
#define kProductionServerDomain         @"api"
#define kQAServerDomain                 @"qa"


typedef NS_ENUM(int8_t, NetworkObserverID) {
    kNetworkObserverIDUnknown = -1,
    kNetworkObserverIDWIFI,
    kNetworkObserverIDNetwork,
    kNetworkObserverIDCortex,
    kNetworkObserverIDCount,
};


@interface SessionManager : NSObject <NSURLSessionDelegate> // <NSURLSessionDataDelegate>


@property (nonatomic,   strong) NSString *baseURLString;
@property (nonatomic, readonly) NSString *baseDomain;
@property (nonatomic,   assign) ServerID serverID;

+ (instancetype)sharedSessionManager;
+ (BOOL)cortexIsReachable;

- (NSString *)domainPrefixForServerID:(ServerID)iID;
- (NSString *)addressForServerID:(ServerID)iID;
- (NSString *)portForServerID:(ServerID)iID;
- (NSString *)urlForServerID:(ServerID)iID;
- (NSString *)webServicesAddress;

- (NetworkObserverID)identifierFor:(id)iObserver;
- (void)startReachabilityNotifiers;
- (BOOL)cellularDataIsAvailable;
- (BOOL)cortexIsReachable;
- (BOOL)wifiIsAvailable;

- (void)invalidateAndCancelAllSessions;
- (void)performDeferredRequestsOnCompletion:(Closure)iCompletion;

//TODO: For every method that uses SessionClosure type, I want the expected SignalType and ErrorType values that will be passed in documented!  Also document the result iObject type to be expected.

#ifdef SESSION_MANAGER_SUPPORTS_VIBES
- (void)pullVibeKind:(VibeKind)iKind sinceVersion:(NSInteger)iVersion onSignal:(SessionClosure)iSignal;
- (void)pullVibeKind:(VibeKind)iKind onSignal:(SessionClosure)iSignal;
- (NSString *)stringForKind:(VibeKind)iKind;

- (void)pushStoredIntensityList:(NSArray *)storedIntensitiesList onSignal:(SessionClosure)iSignal;
- (void)pushStoredIntensityList:(NSArray *)storedIntensitiesList lastSelectedCalm:(NSString*)proirCalm lastSelectedEnergy:(NSString*)proirEnergy onSignal:(SessionClosure)iSignal;
- (void)pullStoredIntensityListOnSignal:(SessionClosure)iSignal;
#endif

#ifdef SESSION_MANAGER_SUPPORTS_ELECTRODES
- (void)pushVibeUsageOnSignal:(SessionClosure)iSignal;
- (void)pullVibeBalanceOnSignal:(SessionClosure)iSignal;
#endif

#ifdef SESSION_MANAGER_SUPPORTS_FIRMWARE
- (void)pullLatestFirmwareDetailsWithData:(NSDictionary*)jsonDict onSignal:(SessionClosure)iSignal;
- (void)pullFirmwareFilesWithData:(NSDictionary *)jsonDict onSignal:(SessionClosure)iSignal;
#endif

#ifdef SESSION_MANAGER_SUPPORTS_USERS
- (void)signInOnSignal:(SessionClosure)iSignal;
- (void)signUpOnSignal:(SessionClosure)iSignal;
- (void)deleteUserOnSignal:(SessionClosure)iSignal;
- (void)pullUserDatafor:(User *)iUser onSignal:(SessionClosure)iSignal;
- (void)pushUpdatedUserData:(User *)iUser onSignal:(SessionClosure)iSignal;
- (void)forgotForEmail:(NSString *)iEmail onSignal:(SessionClosure)iSignal;
- (void)profileImageForForSocial:(Social *)iSocial onSignal:(SessionClosure)iSignal;
#endif

#ifdef SESSION_MANAGER_SUPPORTS_ANALYTICS
- (void)pushSurveyData:(NSData *)iData onSignal:(SessionClosure)iSignal;
- (void)pullGlobalAnalyticsOnSignal:(SessionClosure)iSignal;
#endif

#ifdef SESSION_MANAGER_SUPPORTS_LOGGING
- (void)uploadLoggedValues:(id)jsonObj onSignal:(SessionClosure)signal;
#endif

#ifdef SESSION_MANAGER_SUPPORTS_DEVICE_TRACKING
- (void)captureSerialNumber;
#endif


@end



