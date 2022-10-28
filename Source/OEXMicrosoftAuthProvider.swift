//
//  OEXMicrosoftAuthProvider.swift
//  edX
//
//  Created by Salman on 07/08/2018.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit


class OEXMicrosoftAuthProvider: NSObject, OEXExternalAuthProvider {

    override init() {
        super.init()
    }
    
    var displayName: String  {
        return Strings.microsoft
    }
    
    var backendName: String  {
        return "azuread-oauth2"
    }
    
    func makeAuthView(_ text: String) -> UIView {
        return ExternalProviderButtonView(iconImage: iconImage(), text: text, textStyle: textStyle(), backgroundColor: backgoundColor())
    }
    
    func iconImage() -> UIImage {
        return UIImage(named: "icon_microsoft_white") ?? UIImage()
    }
    
    func backgoundColor() -> UIColor {
        UIColor(hexString: "#2F2F2F", alpha: 1)
    }
    
    func textStyle() -> OEXTextStyle {
        return OEXTextStyle(weight: .normal, size: .large, color: OEXStyles.shared().neutralWhiteT())
    }
    
    func authorizeService(from controller: UIViewController, requestingUserDetails loadUserDetails: Bool, withCompletion completion: @escaping (String?, OEXRegisteringUserDetails?, Error?) -> Void) {
        MicrosoftSocial.shared.loginFromController(controller: controller) { (account, token, error) in
            if let error = error {
                completion(token, nil, error)
            } else if loadUserDetails {
                // load user details
                MicrosoftSocial.shared.getUser(completion: { (user) in
                    let profile = OEXRegisteringUserDetails()
                    
                    guard let account = user.accountClaims,
                        let name = account["name"] as? String,
                        let email = account["email"] as? String else {
                            completion(token, nil, error)
                            return
                    }
                    
                    profile.name = name
                    profile.email = email
                    completion(token, profile, error)
                })
            } else {
                completion(token, nil, error)
            }
        }
    }
}
