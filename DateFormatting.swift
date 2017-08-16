//
//  DateFormatting.swift
//  edX
//
//  Created by Saeed Bashir on 7/20/17.
//  Copyright © 2017 edX. All rights reserved.
//

import Foundation

private let StandardDateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
private let SecondaryDateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZ"
private let StandardDateFormatMicroseconds = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"

/// Time zone set by UserPreferenceAPI
/// The standard date format used all across the edX Platform. Standard ISO 8601
open class DateFormatting: NSObject {
    
    /// Formats a time interval for display as a video duration like 23:35 or 01:14:33
    open class func formatSeconds(asVideoLength totalSeconds: TimeInterval) -> String {
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let minutes = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        let hours = Int(totalSeconds / 3600)
        if hours == 0 {
            return String(format:"%02d:%02d", minutes, seconds)
        }
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// Converts a string in standard ISO8601 format to a date
    open class func date(withServerString dateString: String?) -> NSDate? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = StandardDateFormat
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        
        var result = formatter.date(from: dateString)
        if result == nil {
            // Some APIs return fractional microseconds instead of seconds
            formatter.dateFormat = StandardDateFormatMicroseconds
            result = formatter.date(from: dateString)
        }
        
        return result as NSDate?
    }
    
    /// Format like April 11 or January 23
    open class func format(asMonthDayString date: NSDate?) -> String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        return formatter.string(from: date as Date).uppercased()
    }
    
    /// Format like April 11, 2013
    open class func format(asMonthDayYearString date: NSDate?) -> String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        
        return formatter.string(from: date as Date)
    }
    
    open class func format(asDateMonthYearString date: NSDate) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return formatter.string(from: date as Date)
    }
    
    /// Get current date in the formatted way
    open class func serverString(withDate date: NSDate?) -> String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = StandardDateFormat
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        
        return formatter.string(from: date as Date)
    }
    
    /// Format like 12:00 if same day otherwise April 11, 2013
    open class func format(asMinHourOrMonthDayYearString date: NSDate) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        let order = compareTwoDates(fromDate: Date(), toDate: date as Date)
        formatter.dateFormat = (order == .orderedSame) ? "HH:mm" : "MMM dd, yyyy"
        return formatter.string(from: date as Date).uppercased()
    }
    
    /// Get the order of two dates comparison
    open class func compareTwoDates(fromDate date: Date, toDate: Date) -> ComparisonResult {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMM dd, yyyy"
        let fromDate = formatter.date(from: formatter.string(from: date)) ?? date
        let toDate = formatter.date(from: formatter.string(from: toDate)) ?? toDate
        
        if(fromDate > toDate) {
            return ComparisonResult.orderedDescending
        }
        else if (fromDate < toDate) {
            return ComparisonResult.orderedAscending
        }
        
        return  ComparisonResult.orderedSame
    }
    
    /// Get the time zone abbreivation like PKT, EDT
    open class func timeZoneAbbriviation() -> String{
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        let timeZoneAbbbreviatedDict = TimeZone.abbreviationDictionary
        var abbreviatedKey : String = ""
        for key in timeZoneAbbbreviatedDict.keys {
            if (timeZoneAbbbreviatedDict[key] == formatter.timeZone.identifier) {
                abbreviatedKey = key
                break
            }
        }
        return abbreviatedKey
    }
    
}
