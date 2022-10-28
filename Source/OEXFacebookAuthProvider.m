//
//  OEXFacebookAuthenticationProvider.m
//  edXVideoLocker
//
//  Created by Akiva Leffert on 3/24/15.
//  Copyright (c) 2015 edX. All rights reserved.
//

#import "OEXFacebookAuthProvider.h"

#import "edX-Swift.h"

#import "OEXExternalAuthProviderButton.h"
#import "OEXFBSocial.h"
#import "OEXRegisteringUserDetails.h"
#import <Masonry/Masonry.h>

@implementation OEXFacebookAuthProvider

- (UIColor*)facebookBlue {
    return [UIColor colorWithRed:24.0/255. green:119.0/255. blue:242./255. alpha:1];
}

- (NSString*)displayName {
    return [Strings facebook];
}

- (NSString*)backendName {
    return @"facebook";
}

- (UIView*)makeAuthView:(NSString *)text {
    return [[ExternalProviderView alloc] initWithIconImage:self.iconImage text:text textStyle:self.textStyle backgroundColor:self.backgoundColor borderColor:nil];
}

- (UIImage*)iconImage {
    return [UIImage imageNamed:@"icon_facebook_white"];
}

- (UIColor*)backgoundColor {
    return self.facebookBlue;
}

- (OEXTextStyle*)textStyle {
    return [[OEXMutableTextStyle alloc] initWithWeight:OEXTextWeightNormal size:OEXTextSizeLarge color:[[OEXStyles sharedStyles] neutralWhiteT]];
}

- (void)authorizeServiceFromController:(UIViewController *)controller requestingUserDetails:(BOOL)loadUserDetails withCompletion:(void (^)(NSString * _Nullable, OEXRegisteringUserDetails * _Nullable, NSError * _Nullable))completion {
    OEXFBSocial* facebookManager = [[OEXFBSocial alloc] init]; //could be named facebookHelper.
    [facebookManager loginFromController:controller completion:^(NSString *accessToken, NSError *error) {
        if(error) {
            if([error.domain isEqual:FBSDKErrorDomain] && error.code == FBSDKErrorNetwork) {
                // Hide FB specific errors inside this abstraction barrier
                error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:error.userInfo];
            }
            completion(accessToken, nil, error);
            return;
        }
        if(loadUserDetails) {
            [facebookManager requestUserProfileInfoWithCompletion:^(NSDictionary *userInfo, NSError *error) {
                // userInfo is a facebook user object
                OEXRegisteringUserDetails* profile = [[OEXRegisteringUserDetails alloc] init];
                profile.email = userInfo[@"email"];
                profile.name = userInfo[@"name"];
                completion(accessToken, profile, error);
            }];
        }
        else {
            completion(accessToken, nil, error);
        }
        
    }];
}

@end
