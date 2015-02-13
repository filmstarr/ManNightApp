//
//  ManNightViewController.h
//  ManNight
//
//  Created by Ross Huelin on 17/01/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ManNightViewController : UIViewController<UIWebViewDelegate> {
	IBOutlet UIWebView *mainWebView;
	IBOutlet UIActivityIndicatorView *activityIndicator;
    IBOutlet UIButton *cancelLoadingButton;
    NSString *baseUrl;
    NSString *baseUrlShort;
}

@property(nonatomic,retain) UIWebView *mainWebView;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) UIButton *cancelLoadingButton;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) UIDocumentInteractionController *documentController;

-(IBAction) cancelLoading:(id)sender;
-(void) gotoUrl:(NSString *) urlAddress;
-(void) stoppedLoading;

@end

