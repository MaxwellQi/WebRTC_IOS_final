//
//  CallingViewController.h
//  TVUAnywhere
//
//  Created by zhangqi on 17/10/2016.
//
//

#import <UIKit/UIKit.h>

@interface CallingViewController : UIViewController


- (void)loginWebRTCServer:(NSString *)peerid;
- (BOOL)isHavePhoneCall;


- (IBAction)onpressedbuttonRejectCall:(id)sender;
- (IBAction)onpressedbuttonDismissController:(id)sender;
- (IBAction)onpressedbuttonEndCall:(id)sender;
- (IBAction)onpressedbuttonAcceptCall:(id)sender;



@end
