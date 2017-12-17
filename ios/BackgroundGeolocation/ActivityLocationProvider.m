//
//  ActivityLocationProvider.m
//  BackgroundGeolocation
//
//  Created by Marian Hello on 14/09/2016.
//  Copyright © 2016 mauron85. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ActivityLocationProvider.h"
#import "Activity.h"
#import "SOMotionDetector.h"
#import "LocationController.h"
#import "Logging.h"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

static NSString * const TAG = @"ActivityLocationProvider";
static NSString * const Domain = @"com.marianhello";

@interface ActivityLocationProvider () <SOMotionDetectorDelegate>
@end

@implementation ActivityLocationProvider {
    BOOL isStarted;
    BOOL isTracking;
    SOMotionType lastMotionType;

    LocationController *locationController;
}

- (instancetype) init
{
    self = [super init];
    
    if (self) {
        isStarted = NO;
        isTracking = NO;
    }
    
    return self;
}

- (void) onCreate {
    locationController = [LocationController sharedInstance];
    locationController.delegate = self;

    SOMotionDetector *motionDetector = [SOMotionDetector sharedInstance];
    motionDetector.delegate = self;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        motionDetector.useM7IfAvailable = YES; //Use M7 chip if available, otherwise use lib's algorithm
    }
}

- (BOOL) onConfigure:(Config*)config error:(NSError * __autoreleasing *)outError
{
    DDLogVerbose(@"%@ configure", TAG);
    
    locationController.pausesLocationUpdatesAutomatically = [config pauseLocationUpdates];
    locationController.activityType = [config decodeActivityType];
    locationController.distanceFilter = config.distanceFilter.integerValue; // meters
    locationController.desiredAccuracy = [config decodeDesiredAccuracy];
    
    return YES;
}

- (BOOL) onStart:(NSError * __autoreleasing *)outError
{
    DDLogInfo(@"%@ will start", TAG);
    
    if (!isStarted) {
        [[SOMotionDetector sharedInstance] startDetection];
        isStarted = YES;
    }
    
    return YES;
}

- (BOOL) onStop:(NSError * __autoreleasing *)outError
{
    DDLogInfo(@"%@ will stop", TAG);
    
    if (isStarted) {
        [[SOMotionDetector sharedInstance] stopDetection];
        [self stopTracking];
        isStarted = NO;
    }
    
    return YES;
}

- (void) startTracking
{
    if (isTracking) {
        return;
    }

    NSError *error = nil;
    if ([locationController start:&error]) {
        isTracking = YES;
    } else {
        [self.delegate onError:error];
    }
}

- (void) stopTracking
{
    if (isTracking) {
        [locationController stop:nil];
        isTracking = NO;
    }
}

- (void) onSwitchMode:(BGOperationMode)mode
{
    /* do nothing */
}

- (void) onAuthorizationChanged:(BGAuthorizationStatus)authStatus
{
    [self.delegate onAuthorizationChanged:authStatus];
}

- (void) onLocationsChanged:(NSArray*)locations
{
    if (lastMotionType == MotionTypeNotMoving) {
        [self stopTracking];
    }

    for (CLLocation *location in locations) {
        Location *bgloc = [Location fromCLLocation:location];
        [self.delegate onLocationChanged:bgloc];
    }
}

- (void)motionDetector:(SOMotionDetector *)motionDetector motionTypeChanged:(SOMotionType)motionType
{
    lastMotionType = motionType;

    if (motionType != MotionTypeNotMoving) {
        [self startTracking];
    } else {
        // we delay tracking stop after location is found
    }

    NSString *type = @"";
    switch (motionType) {
        case MotionTypeNotMoving:
            type = @"STILL";
            break;
        case MotionTypeWalking:
            type = @"WALKING";
            break;
        case MotionTypeRunning:
            type = @"RUNNING";
            break;
        case MotionTypeAutomotive:
            type = @"IN_VEHICLE";
            break;
    }
    
    DDLogDebug(@"%@ motionTypeChanged: %@", TAG, type);
    [self notify:[NSString stringWithFormat:@"%@ activity detected: %@ activity", TAG, type]];
    
    Activity *activity = [[Activity alloc] init];
    activity.type = type;
    
    [super.delegate onActivityChanged:activity];
}

- (void) onError:(NSError*)error
{
    [self.delegate onError:error];
}

- (void) onPause:(CLLocationManager*)manager
{
    [self.delegate onLocationPause];
}

- (void) onResume:(CLLocationManager*)manager
{
    [self.delegate onLocationResume];
}

- (void) onDestroy {
    DDLogInfo(@"Destroying %@ ", TAG);
    [self onStop:nil];
}

@end
