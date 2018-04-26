//
//  UITextView+Swift.swift
//  edX
//
//  Created by Zeeshan Arif on 4/25/18.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit

private enum AgreementType {
    case signIn
    case signUp
}

extension UITextView {
    
    private func setupAgreement(for type: AgreementType) {
        let style = OEXMutableTextStyle(weight: .normal, size: .base, color: OEXStyles.shared().neutralDark())
        style.lineBreakMode = .byWordWrapping
        style.alignment = .left
        let platformName = OEXConfig.shared().platformName()
        let prefix: String
        switch type {
        case .signIn:
            prefix = Strings.agreementTextPrefixSignin
            break
        case .signUp:
            prefix = Strings.agreementTextPrefixSignup
            break
        }
        let eulaText = Strings.agreementLinkTextEula(platformName: platformName)
        let tosText = Strings.agreementLinkTextTos(platformName: platformName)
        let privacyPolicyText = Strings.agreementLinkTextPrivacyPolicy
        let agreementText = "\(prefix)\(Strings.agreementText(eula: eulaText, tos: tosText, privacyPolicy: privacyPolicyText))"
        var attributedString = style.attributedString(withText: agreementText)
        if let eulaUrl = Bundle.main.url(forResource: "Mobile_App_Eula", withExtension: "htm"),
            let tosUrl = Bundle.main.url(forResource: "Terms-and-Services", withExtension: "htm"),
            let privacyPolicyUrl = Bundle.main.url(forResource: "privacy_policy", withExtension: "htm") {
            attributedString = attributedString.addLink(on: eulaText, value: eulaUrl)
            attributedString = attributedString.addLink(on: tosText, value: tosUrl)
            attributedString = attributedString.addLink(on: privacyPolicyText, value: privacyPolicyUrl)
        }
        attributedText = attributedString
    }
    
    @objc func setupAgreementForSignInScreen() {
        setupAgreement(for: .signIn)
    }
    
    @objc func setupAgreementForSignUpScreen() {
        setupAgreement(for: .signUp)
    }
    
}
