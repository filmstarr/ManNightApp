//
//  ManNightAppDelegate.m
//  ManNight
//
//  Created by Ross Huelin on 17/01/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ManNightAppDelegate.h"
#import "ManNightViewController.h"
#import <Parse/Parse.h>

@implementation ManNightAppDelegate

@synthesize window, manNightViewController;
NSDictionary *notificationUserInfo;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //Load up default values
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
	baseUrl = [standardUserDefaults stringForKey:@"BaseUrl"];
    
    //Load main view controller
    [self.window setRootViewController: manNightViewController];
    [self.window addSubview:[manNightViewController view]];
    [self.window makeKeyAndVisible];
    
    //Setup Parse
    [Parse setApplicationId:@"ENTER YOUR APP ID HERE" clientKey:@"ENTER YOUR CLIENT ID"];
    
    // Register for Push Notitications, if running iOS 8
    UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes categories:nil];
        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications];
    
    //Process any notification that we may have received
    NSDictionary *userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo) {
        [self gotoTopicFromNotificationInfo:userInfo];
    }
    
	return YES;
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	//Update the current device token
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];		
	if (standardUserDefaults) {
        [standardUserDefaults setObject:deviceToken forKey:@"deviceToken"];
	}
}  

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error  
{  
	// Inform the user that registration failed
	NSString* failureMessage = @"There was an error while trying to register for push notifications.";  
	UIAlertView* failureAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:failureMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[failureAlert show];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	NSString *message;
	if ([[userInfo allKeys] containsObject:@"aps"]) { 
		
		if([[[userInfo objectForKey:@"aps"] allKeys] containsObject:@"alert"]) {
			
			NSDictionary *alertDict = [userInfo objectForKey:@"aps"];
			
			if ([[alertDict objectForKey:@"alert"] isKindOfClass:[NSString class]]) {
				// The alert is a single string message so we can display it
				message = [alertDict valueForKey:@"alert"];
			}
            else {
				// The alert is a a dictionary with more details, let's just get the message without localization
				// This should be customized to fit your message details or usage scenario
				message = [[alertDict valueForKey:@"alert"] valueForKey:@"body"];
			}
		}
        else {
			// There was no Alert content - there may be badge, sound or other info
			message = @"New Post";
		}
		
	} else {
		// There was no Apple Push content - there may be custom JSON	
		message = @"No APS content";
	}
	
	if (!appWillEnterForeground)
	{
        [self updateBadges];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Man Night" message: message delegate: self cancelButtonTitle: @"Close" otherButtonTitles: @"View", nil];
        notificationUserInfo = userInfo;
		[alert show];
	}
	else {
        [self gotoTopicFromNotificationInfo:userInfo];
	}
	appWillEnterForeground = NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        [self gotoTopicFromNotificationInfo:notificationUserInfo];
    }
}

- (void)gotoTopicFromNotificationInfo:(NSDictionary *)userInfo {
    //Navigate to url	
    NSString *topic;
    
    if ([[userInfo allKeys] containsObject:@"topic"]) { 
        if ([[userInfo objectForKey:@"topic"] isKindOfClass:[NSString class]]) {
            topic = [userInfo valueForKey:@"topic"];
            NSString *urlAddress = [NSString stringWithFormat:@"%@/%@", baseUrl, topic];
            [manNightViewController gotoUrl: urlAddress];
        }
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
	UIApplication *app = [UIApplication sharedApplication];
	// Request permission to run in the background. Provide an
	// expiration handler in case the task runs long.
	NSAssert(bgTask == UIBackgroundTaskInvalid, nil);
	bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
		// Synchronize the cleanup call on the main thread in case
		// the task actually finishes at around the same time.
		dispatch_async(dispatch_get_main_queue(), ^{
			if (bgTask != UIBackgroundTaskInvalid)
			{
				[app endBackgroundTask:bgTask];
				bgTask = UIBackgroundTaskInvalid;
			}
		});
	}];
	// Start the long-running task and return immediately.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// Do the work associated with the task.
		[self unreadTopics];
		// Synchronize the cleanup call on the main thread in case
		// the expiration handler is fired at the same time.
		dispatch_async(dispatch_get_main_queue(), ^{
			if (bgTask != UIBackgroundTaskInvalid)
			{
				[app endBackgroundTask:bgTask];
				bgTask = UIBackgroundTaskInvalid;
			}
		});
	});
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of the transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	
	appWillEnterForeground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    if (appWillEnterForeground)
    {
        [self updateBadges];
        appWillEnterForeground = NO;
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
}

- (void) unreadTopics {
	//Get the number of unread topics
    NSString *stringNewPostsUrl = [[NSString alloc] initWithFormat: @"%@%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"BaseUrl"], @"/index.php?action=unreadcount;all;"];
	NSURL* urlNewPosts = [NSURL URLWithString:stringNewPostsUrl];
	NSString *stringNewPosts = [[NSString alloc] initWithContentsOfURL:urlNewPosts usedEncoding:nil error:nil];
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	if ([f numberFromString: stringNewPosts])
	{
		[[UIApplication sharedApplication] setApplicationIconBadgeNumber:([stringNewPosts intValue])];			
	}
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

#pragma mark -
#pragma mark Update badges

- (void) updateBadges {
    UIWebView *mainWebView = [manNightViewController mainWebView];
    NSString *toolbar = [mainWebView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML"];
    if ([toolbar rangeOfString:@"id=\"toolbar\""].location != NSNotFound)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *badgeString = [self getBadgeString];
            NSArray *countArray = [badgeString componentsSeparatedByString:@","];
            
            if ([countArray count] == 2)
            {
                NSString *stringNewMessages = [countArray objectAtIndex:0];
                NSString *stringNewPosts = [countArray objectAtIndex:1];
                
                NSNumberFormatter *messageFormatter = [[NSNumberFormatter alloc] init];
                NSNumberFormatter *postFormatter = [[NSNumberFormatter alloc] init];
                if ([messageFormatter numberFromString: stringNewMessages] && [postFormatter numberFromString: stringNewPosts])
                {
                    int messageCount = [stringNewMessages intValue];
                    int postCount = [stringNewPosts intValue];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setBadges:messageCount :postCount];
                    });
                }
            }
        });
    }
}

-(NSString*) getBadgeString {
    NSString *stringNewPostsUrl = [[NSString alloc] initWithFormat: @"%@%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"BaseUrl"], @"/index.php?action=unreadcount;all;countString;"];
	NSURL* urlNewPosts = [NSURL URLWithString:stringNewPostsUrl];
	return [[NSString alloc] initWithContentsOfURL:urlNewPosts usedEncoding:nil error:nil];
}

-(void) setBadges: (int)messageCount :(int)postCount {
    UIWebView *mainWebView = [manNightViewController mainWebView];
    
    //Set count bages
    NSString *updateMessages = [NSString stringWithFormat:@"$('.unread-messages').last().html('%d');", messageCount];
    NSString *updatePosts = [NSString stringWithFormat:@"$('.unread-posts').last().html('%d');", postCount];
    [mainWebView stringByEvaluatingJavaScriptFromString: updateMessages];
    [mainWebView stringByEvaluatingJavaScriptFromString: updatePosts];
    
    //Show or hide count badges
    if (messageCount != 0) {
        [mainWebView stringByEvaluatingJavaScriptFromString: @"$('.unread-messages').last().show();" ];
    } else {
        [mainWebView stringByEvaluatingJavaScriptFromString: @"$('.unread-messages').last().hide();" ];
    }
    if (postCount != 0) {
        [mainWebView stringByEvaluatingJavaScriptFromString: @"$('.unread-posts').last().show();" ];
    } else {
        [mainWebView stringByEvaluatingJavaScriptFromString: @"$('.unread-posts').last().hide();" ];
    }
}

@end
