//
//  ManNightAppDelegate.h
//  ManNight
//
//  Created by Ross Huelin on 17/01/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ManNightViewController.h"

@interface ManNightAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    ManNightViewController *manNightViewController;
	UIBackgroundTaskIdentifier bgTask;
	BOOL appWillEnterForeground;
    NSString *baseUrl;
}

@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet ManNightViewController *manNightViewController;

-(void) unreadTopics;
-(void) gotoTopicFromNotificationInfo:(NSDictionary *) userInfo;

@end





