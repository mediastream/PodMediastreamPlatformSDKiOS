//
//  MediastreamPlayerConfig.swift
//  Pods
//
//  Created by Adler Oliveira on 6/8/16.
//
//

open class MediastreamPlayerConfig {
    public init () {}
    
    public enum VideoTypes: String {
        case LIVE = "live-stream"
        case VOD = "video"
    }
    
    public enum Environments: String {
        case PRODUCTION = "https://mdstrm.com"
        case DEV = "https://develop.mdstrm.com"
    }
    
    fileprivate var _accessToken: String?
    fileprivate var _accountID: String?
    fileprivate var _adCustomAttributes: [(String, String)] = []
    fileprivate var _adURL: String?
    fileprivate var _analyticsCustom: String?
    fileprivate var _appCertificateUrl: String?
    fileprivate var _autoplay: Bool = false
    fileprivate var _customUI: Bool = true
    fileprivate var _customerID: String?
    fileprivate var _debug: Bool = false
    fileprivate var _dvr: Bool = false
    fileprivate var _drmHeaders: [(String, String)] = []
    fileprivate var _drmUrl: String?
    fileprivate var _environment = Environments.PRODUCTION
    fileprivate var _id: String?
    fileprivate var _src: String?
    fileprivate var _maxProfile: String?
    fileprivate var _referer: String?
    fileprivate var _showControls: Bool = true
    fileprivate var _type = VideoTypes.VOD
    fileprivate var _volume: Int?
    fileprivate var _windowDvr: Int = 0
    fileprivate var _defaultOrientation: UIInterfaceOrientation?
    fileprivate var _showDismissButton: Bool = false
    fileprivate var _showCastButton: Bool = false
    
    open var accessToken: String? {
        get { return _accessToken }
        set (val) { _accessToken = val }
    }
    
    open var accountID: String? {
        get { return _accountID }
        set (val) { _accountID = val }
    }
    
    open func addAdCustomAttribute(_ key: String, value: String) {
        _adCustomAttributes.append((key, value))
    }
    
    open var adURL: String? {
        get { return _adURL }
        set (val) { _adURL = val }
    }
    
    open func addDrmHeader(_ key: String, value: String) {
        _drmHeaders.append((key, value))
    }
    
    open var analyticsCustom: String? {
        get { return _analyticsCustom }
        set (val) { _analyticsCustom = val }
    }
    
    open var appCertificateUrl: String? {
        get { return _appCertificateUrl }
        set (val) { _appCertificateUrl = val }
    }
    
    open var autoplay: Bool {
        get { return _autoplay }
        set (val) { _autoplay = val}
    }

    open var customerID: String? {
        get { return _customerID }
        set (val) { _customerID = val }
    }
    
    open var debug: Bool {
        get { return _debug }
        set (val) { _debug = val }
    }
    
    open var defaultOrientation: UIInterfaceOrientation? {
        get { return _defaultOrientation }
        set (val) { _defaultOrientation = val }
    }
    
    open var dvr: Bool {
        get { return _dvr }
        set (val) { _dvr = val }
    }
    
    open var customUI: Bool {
        get { return _customUI }
        set (val) { _customUI = val }
    }
    
    open var drmHeaders: [(String, String)] {
        return _drmHeaders
    }
    
    open var drmUrl: String? {
        get { return _drmUrl }
        set (val) { _drmUrl = val }
    }
    
    open var environment: Environments {
        get { return _environment }
        set (val) { _environment = val }
    }
    
    open var id: String? {
        get { return _id }
        set (val) { _id = val }
    }
    
    open var maxProfile: String? {
        get { return _maxProfile }
        set (val) { _maxProfile = val }
    }
    
    open var showControls: Bool {
        get { return _showControls }
        set (val) { _showControls = val}
    }
    
    open var showDismissButton: Bool {
        get { return _showDismissButton }
        set (val) { _showDismissButton = val }
    }
    
    open var showCastButton: Bool {
        get { return _showCastButton }
        set (val) { _showCastButton = val }
    }
    
    open var src: String? {
        get { return _src }
        set (val) { _src = val }
    }
    
    open var referer: String? {
        get { return _referer }
        set (val) { _referer = val }
    }
    
    open var type: VideoTypes {
        get { return _type }
        set (val) { _type = val }
    }
    
    open var volume: Int {
        get { return _volume == nil ? -1 : _volume! }
        set (val) { _volume = val }
    }
    
    open var windowDvr: Int {
        get { return _windowDvr }
        set (val) { _windowDvr = val }
    }
    
    //Methods:
    open func hasAds() -> Bool {
        return _adURL != nil
    }
    
    open func getAdQueryString() -> String {
        return "?mobile=true" + _adCustomAttributes.map(queryString).joined(separator: "")
    }
    
    open func getMediaQueryString() -> String {
        var mediaInfo = "?sdk=true&dnt=true"
        if _customerID != nil {
            mediaInfo += "&c=" + customerID!
        }
        if _accessToken != nil {
            mediaInfo += "&access_token=" + accessToken!
        }
        if _maxProfile != nil {
            mediaInfo += "&max_profile=" + maxProfile!
        }
        if _type == VideoTypes.LIVE && _dvr && _windowDvr > 0 {
            mediaInfo += "&dvrOffset=" + String(_windowDvr)
        }
        return mediaInfo
    }
    
    fileprivate func queryString(_ attribute: (String, String)) -> String {
        return "&\(attribute.0)=\(attribute.1)"
    }
}
