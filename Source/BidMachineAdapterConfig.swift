// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation


/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class BidMachineAdapterConfiguration: NSObject {
    private static let COPPA_KEY = "com.chartboost.adapter.bidmachine.coppa"
    private static let GDPR_ZONE_KEY = "com.chartboost.adapter.bidmachine.gdprzone"
    private static let GDPR_CONSENT_KEY = "com.chartboost.adapter.bidmachine.gdprconsent"
    private static let US_PRIVACY_STRING = "com.chartboost.adapter.bidmachine.usprivacystring"
    // IAB US Privacy String defined at: https://github.com/InteractiveAdvertisingBureau/USPrivacy/blob/master/CCPA/US%20Privacy%20String.md
    // "1NN-" = Specification v1, no notice given, user has not opted-out, LSPA not applicable
    private static let DEFAULT_PRIVACY_STRING = "1NN-"

    /// Flag that specifies whether the BidMachine SDK starts up in test mode
    /// Default value is 'false'
    @objc public static var testMode: Bool = false

    /// Flag that specifies whether BidMachine SDK logging mode is on
    /// Default value is 'false'
    @objc public static var logging: Bool = false

    /// Flag that specifies whether the BidMachine SDK bid logging is on
    /// Default value is 'false'
    @objc public static var bidLogging: Bool = false

    /// Flag that specifies whether the BidMachine SDK event logging is on
    /// Default value is 'false'
    @objc public static var eventLogging: Bool = false


    // 'UserDefaults.standard.string(forKey:)' returns 'nil' if there is no value for a key.
    // But 'UserDefaults.standard.bool(forKey:)' returns 'false' if there is no value for a key.
    // So for bool values we need to explicitly check to see if there's already a
    // stored value in order to apply default values other than false.

    @objc public static var coppa: Bool {
        get { 
            // If the value hasn't been stored during a previous launch, default to true
            if UserDefaults.standard.object(forKey: COPPA_KEY) == nil {
                UserDefaults.standard.setValue(true, forKey: COPPA_KEY)
            }
            return UserDefaults.standard.bool(forKey: COPPA_KEY)
        }
        set { UserDefaults.standard.setValue(newValue, forKey: COPPA_KEY) }
    }

    @objc public static var gdprZone: Bool {
        get {
            // If the value hasn't been stored during a previous launch, default to true
            if UserDefaults.standard.object(forKey: GDPR_ZONE_KEY) == nil {
                UserDefaults.standard.setValue(true, forKey: GDPR_ZONE_KEY)
            }
            return UserDefaults.standard.bool(forKey: GDPR_ZONE_KEY)
        }
        set { UserDefaults.standard.setValue(newValue, forKey: GDPR_ZONE_KEY) }
    }

    @objc public static var gdprConsent: Bool {
        get {
            // Will default to 'false' if there is no stored value
            return UserDefaults.standard.bool(forKey: GDPR_CONSENT_KEY)
        }
        set { UserDefaults.standard.setValue(newValue, forKey: GDPR_CONSENT_KEY) }
    }

    @objc public static var usPrivacyString: String {
        get {
            // If the value hasn't been stored during a previous launch, use safe default
            return UserDefaults.standard.string(forKey: US_PRIVACY_STRING) ?? DEFAULT_PRIVACY_STRING
        }
        set { UserDefaults.standard.setValue(newValue, forKey: US_PRIVACY_STRING) }
    }
}
