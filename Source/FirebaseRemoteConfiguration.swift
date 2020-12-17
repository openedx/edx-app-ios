//
//  FirebaseRemoteConfiguration.swift
//  edX
//
//  Created by Salman on 04/11/2020.
//  Copyright © 2020 edX. All rights reserved.
//

import UIKit

private let remoteConfigUserDefaultKey = "remote-config"

protocol RemoteConfigProvider {
  var remoteConfig: FirebaseRemoteConfiguration { get }
}

extension RemoteConfigProvider {
  var remoteConfig: FirebaseRemoteConfiguration {
    return FirebaseRemoteConfiguration.shared
  }
}

fileprivate enum remoteConfigKeys: String, RawStringExtractable {
    case valuePropEnabled = "VALUE_PROP_ENABLED"
}

@objc class FirebaseRemoteConfiguration: NSObject {
    @objc static let shared =  FirebaseRemoteConfiguration()
    var isValuePropEnabled: Bool = false
    
    private override init() {
        super.init()
    }
    
    @objc func initialize(remoteConfig: RemoteConfig) {
        isValuePropEnabled = remoteConfig.configValue(forKey: remoteConfigKeys.valuePropEnabled.rawValue).boolValue
        UserDefaults.standard.set(isValuePropEnabled, forKey: remoteConfigUserDefaultKey)
        UserDefaults.standard.synchronize()
    }
    
    @objc func initialize() {
        guard let value = UserDefaults.standard.object(forKey: remoteConfigUserDefaultKey) as? Bool else {
            return
        }
        
        isValuePropEnabled = value
    }
}
