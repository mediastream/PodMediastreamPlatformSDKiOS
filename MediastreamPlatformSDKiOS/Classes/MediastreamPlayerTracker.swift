//
//  MediastreamPlayerTracker.swift
//  MediastreamPlatformSDK
//
//  Created by Adler Oliveira on 11/7/16.
//  Copyright © 2016 Mediastream. All rights reserved.
//

import Foundation
import AVFoundation
import AVKit

open class MediastreamPlayerTracker: NSObject {
    private var TRACK_HOST: String
    private static var TRACK_HOST_PROD = "https://track.mdstrm.com/"
    private static var TRACK_HOST_DEV = "https://qa.track.mdstrm.com/"
    private static var PING_INTERVAL_SECONDS = 30
    private var firstStart: Bool
    private var config: MediastreamPlayerConfig
    private var SDK: MediastreamPlatformSDK
    private var uniqueId: String
    private var pingTimer: Timer?
    private var canPlayDate: Date?
    private var wasInit: Bool
    
    public init (config: MediastreamPlayerConfig, SDK: MediastreamPlatformSDK) {
        self.config = config
        if config.environment == MediastreamPlayerConfig.Environments.PRODUCTION {
            self.TRACK_HOST = MediastreamPlayerTracker.TRACK_HOST_PROD
        } else {
            self.TRACK_HOST = MediastreamPlayerTracker.TRACK_HOST_DEV
        }
        self.SDK = SDK
        self.firstStart = true
        self.uniqueId = self.SDK.getUniqueId()
        wasInit = true
    }
    
    open func wasTrackerInitialized() -> Bool {
        return self.wasInit
    }
    
    open func setCanPlayDate(canPlayDate: Date) {
        self.canPlayDate = canPlayDate
    }
    
    open func startTrackPing() {
        if self.pingTimer == nil || !(self.pingTimer?.isValid)! {
            if self.config.debug {
                NSLog("MediastreamPlayerTracker: TrackPing start")
            }
            
            self.pingTimer = Timer.scheduledTimer(
                timeInterval: TimeInterval(MediastreamPlayerTracker.PING_INTERVAL_SECONDS),
                target: self,
                selector: #selector(MediastreamPlayerTracker.pingTask),
                userInfo: nil,
                repeats: true
            )
            
            self.pingTimer?.fire()
        }
    }
    
    open func stopTrackPing() {
        if self.config.debug {
            NSLog("MediastreamPlayerTracker: TrackPing stop")
        }
        
        if self.pingTimer != nil {
            self.pingTimer?.invalidate()
            self.pingTimer = nil
        }
    }
    
    open func track(firstStart: Bool) {
        let queryString = self.getUrlQueryString()
        var type = "media"
        var trackUrl = self.TRACK_HOST
        
        if self.config.type == MediastreamPlayerConfig.VideoTypes.LIVE {
            type = "live"
        }
        
        if firstStart {
            trackUrl += "s/"
        }
        trackUrl += "track/\(self.SDK.getSessionID())/\(type)/\(String(describing: self.config.id!))\(queryString)"
        
        if self.config.debug {
            NSLog("MediastreamPlayerTracker: Tracking to \(trackUrl)")
        }
        
        if firstStart {
            NSLog("MediastreamPlayerTracker: Setting firstStart to false")
            self.firstStart = false
        }
        
        NSLog("trackURL: \(trackUrl)")
        let request = NSMutableURLRequest(url: URL(string: trackUrl)!)
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(UAString(), forHTTPHeaderField: "User-Agent")
        if self.config.debug {
            NSLog("MediastreamPlayerTracker: User-Agent \(UAString())")
        }
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
            if error != nil {
                print(error!.localizedDescription)
            }
            guard let data = data else {return}
            if self.config.debug {
                NSLog("MediastreamPlayerTracker: Track request data \(data)")
                NSLog("MediastreamPlayerTracker: Track request response \(String(describing: response))")
                NSLog("MediastreamPlayerTracker: Track request data error \(String(describing: error))")
            }
        })
        task.resume()
    }
    
    open func getUrlQueryString() -> String {
        var queryString = "?LE=\(String(describing: self.config.accountID!))"
        if self.config.customerID != nil {
            queryString += "&YB=\(String(describing: self.config.customerID!))"
        }
        if self.config.analyticsCustom != nil {
            queryString += "&CU=\(String(describing: self.config.analyticsCustom!))"
        }
        if self.config.referer != nil {
            queryString += "&ref=\(String(describing: self.config.referer!))"
        }
        queryString += "&Wo=\(self.SDK.getSessionID())"
        queryString += "&iG=\(self.uniqueId)"
        queryString += "&jE=\(String(MediastreamPlayerTracker.PING_INTERVAL_SECONDS))"
        queryString += "&Vv=\(String(self.SDK.getWaitingCount()))"
        
        let height = self.SDK.getHeight()
        if height > 0 {
            queryString += "&VH=\(height)"
        }
        
        let bitrate = self.SDK.getBitrate()
        if bitrate > 0 {
            queryString += "&cP=\(bitrate)"
        }
        
        let bandwidth = self.SDK.getBandwidth()
        if bandwidth > 0 {
            queryString += "&bw=\(bandwidth)"
        }
        
        let duration = self.SDK.getDuration()
        if duration > 0 {
            queryString += "&mD=\(duration)"
        }
        
        let currentTime = self.SDK.getCurrentPosition()
        if currentTime > 0 {
            queryString += "&CT=\(currentTime)"
        }
        
        let hostname = self.SDK.getHostname()
        if hostname != "" {
            queryString += "&es=\(hostname)"
        }
        
        queryString += "&pt=ios-sdk-native"
        
        if self.firstStart && self.canPlayDate != nil {
            queryString += "&DU=\(String(NSDate().timeIntervalSince1970 - (self.canPlayDate?.timeIntervalSince1970)!))"
        }
        
        queryString += "&_=\(String(NSDate().timeIntervalSince1970))"
        
        return queryString
    }
    
    @objc open func pingTask() {
        if self.config.debug {
            NSLog("MediastreamPlayerTracker: Performing pingTask")
        }
        
        self.track(firstStart: false)
        if self.firstStart {
            self.track(firstStart: true)
        }
        
        self.SDK.clearWaitingCount()
    }
    
    
    //eg. Darwin/16.3.0
    func DarwinVersion() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let dv = String(bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        return "Darwin/\(dv)"
    }
    //eg. CFNetwork/808.3
    func CFNetworkVersion() -> String {
        let dictionary = Bundle(identifier: "com.apple.CFNetwork")?.infoDictionary!
        let version = dictionary?["CFBundleShortVersionString"] as! String
        return "CFNetwork/\(version)"
    }
    
    //eg. iOS/10_1
    func deviceVersion() -> String {
        let currentDevice = UIDevice.current
        return "\(currentDevice.systemName)/\(currentDevice.systemVersion)"
    }
    //eg. iPhone5,2
    func deviceName() -> String {
        return "iPhone"
        /*var sysinfo = utsname()
        uname(&sysinfo)
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)*/
    }
    //eg. MyApp/1
    func appNameAndVersion() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let name = dictionary["CFBundleName"] as! String
        return "\(name)/\(version)"
    }
    
    func UAString() -> String {
        return "\(appNameAndVersion()) \(deviceName()) \(deviceVersion()) \(CFNetworkVersion()) \(DarwinVersion())"
    }
}
