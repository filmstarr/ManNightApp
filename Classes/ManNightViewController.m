//
//  ManNightViewController.m
//  ManNight
//
//  Created by Ross Huelin on 17/01/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ManNightViewController.h"
#import <Parse/Parse.h>

@implementation ManNightViewController

@synthesize mainWebView, activityIndicator, cancelLoadingButton, refreshControl, documentController;

- (void) gotoUrl: (NSString *) urlAddress  {
    NSString *head = [mainWebView stringByEvaluatingJavaScriptFromString:@"document.head.innerHTML"];
    if ([head rangeOfString:@"jquery.mobile"].location == NSNotFound) {
        NSURL *url = [NSURL URLWithString:urlAddress];
        NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
        [mainWebView loadRequest:requestObj];
    } else {
        NSString *javascript = [NSString stringWithFormat:@"$.mobile.changePage('%@', { reloadPage : true })", urlAddress];
        [mainWebView stringByEvaluatingJavaScriptFromString: javascript ];
    }
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
-(void)viewDidLoad {
    //Hide webview until loaded
    cancelLoadingButton.hidden = NO;
    [activityIndicator startAnimating];
    mainWebView.hidden = YES;
    
    //Get parameters
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	baseUrl = [standardUserDefaults stringForKey:@"BaseUrl"];
    baseUrlShort = [standardUserDefaults stringForKey:@"BaseUrlShort"];
        
    //Remove shadows
    for (UIView *view in [[[mainWebView subviews] objectAtIndex:0] subviews]) { 
        if ([view isKindOfClass:[UIImageView class]]) view.hidden = YES;
    }
    
	//Load the main forum page
    [self gotoUrl: baseUrl];
	[super viewDidLoad];
    
    //Add refresh control
    mainWebView.delegate = (id)self;
    refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [mainWebView.scrollView insertSubview:refreshControl atIndex:0];
    
    //Round button corners
    cancelLoadingButton.layer.cornerRadius = 25;
    cancelLoadingButton.clipsToBounds = YES;
}

#pragma mark Navigation Methods

-(IBAction)cancelLoading:(id) sender {
    [mainWebView stopLoading];
    [self stoppedLoading];
}

#pragma mark End Navigation Methods


#pragma mark Loading WebView

-(BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	NSString *urlAddress = [url absoluteString];

	if ([urlAddress rangeOfString:@"action=login" options:NSCaseInsensitiveSearch].location != NSNotFound && [urlAddress rangeOfString:@"member=" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		//Get member id
		NSRange find;
		find = [urlAddress rangeOfString:@"member="];
		NSString *userId = [urlAddress substringFromIndex:find.location + find.length];
		find = [userId rangeOfString:@";"];
		if (find.location != NSNotFound) {
			userId = [userId substringToIndex:find.location];
		}

		//Save user alias
		NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];		
		if (standardUserDefaults) {
			[standardUserDefaults setObject:userId forKey:@"Alias"];
			[standardUserDefaults synchronize];
		}
		
        //Register with Parse
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation setDeviceTokenFromData: [standardUserDefaults objectForKey:@"deviceToken"]];
        [currentInstallation setValue:userId forKey:@"userId"];
        [currentInstallation saveInBackground];
    }
	
	//User clicked on a link
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([[url query] length] == 0 || [[url query] rangeOfString: @"openFileInNewWindow="].location == NSNotFound) {
            //Open Url if we aren't navigating away from the baseUrl
            if([urlAddress rangeOfString:baseUrlShort options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return YES;
            }
            else {
                [[UIApplication sharedApplication] openURL:url];
                return NO;
            }
        }
        else {
            //Download file and present in document interaction controller
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
            [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *respData, NSError *error){
                
                NSRange range = [[url query] rangeOfString:@"openFileInNewWindow="];
                NSUInteger start = range.location + range.length;
                NSUInteger length = [[url query] length] - start;
                
                NSString *fileName = [[url query] substringWithRange:NSMakeRange(start, length)];
                fileName = [fileName stringByReplacingOccurrencesOfString:@"+" withString:@" "];
                
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
                NSError *fileError = nil;
                BOOL success = [respData writeToFile:path options:NSDataWritingFileProtectionComplete error:&fileError];
                    
                if (success) {
                    documentController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:path]];
                    [documentController presentOptionsMenuFromRect:CGRectZero inView:self.view animated:YES];
                } else {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Sorry, the document requested could not be opened." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [alert show];
                }
            }];
            return NO;
        }
	}

	return YES;   
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    mainWebView.hidden = NO;
    [self stoppedLoading];
}

- (void)stoppedLoading {
    [activityIndicator stopAnimating];
    cancelLoadingButton.hidden = YES;
    [refreshControl endRefreshing];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    mainWebView.hidden = NO;
    [self stoppedLoading];
    if ([error code] != -999) {
        [self stoppedLoading];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"No forum connection could be established." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
    }
}

#pragma mark Loading WebView


#pragma mark Device Rotation

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSUInteger) supportedInterfaceOrientations {
    if (mainWebView.hidden)
    {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    else
    {
        return UIInterfaceOrientationMaskAll;
    }
}

#pragma mark End Device Rotation


#pragma mark Other Stuff

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)handleRefresh:(UIRefreshControl *)refresh {
    cancelLoadingButton.hidden = NO;
    [activityIndicator startAnimating];
    if([mainWebView.request.URL.absoluteString rangeOfString:baseUrlShort options:NSCaseInsensitiveSearch].location != NSNotFound) {
      [mainWebView reload];
    }
    else {
      [self gotoUrl: baseUrl];
    }
}

#pragma mark End Other Stuff


@end
