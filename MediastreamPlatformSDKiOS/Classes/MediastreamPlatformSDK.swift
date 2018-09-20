//
//  MediastreamPlatformSDK.swift
//  MediastreamPlatformSDKiOS
//
//  Created by Carlos Ruiz on 9/20/18.
//

import AVFoundation
import AVKit
import GoogleInteractiveMediaAds

open class MediastreamPlatformSDK: UIViewController, IMAAdsLoaderDelegate, IMAAdsManagerDelegate {
    let reachability = MediastreamPlayerReachability()
    var tracker: MediastreamPlayerTracker?
    var config: MediastreamPlayerConfig?
    var playRequest = false
    var initVolume: Int?
    var playerTime: Double?
    var waitingCount = 0
    var imageURL: URL?
    var isPlayerPlaying = false
    var isMuted = false
    var isWaiting = false
    var isFullscreen = false
    var isFullscreenRotated = false
    var isShowingUI = true
    var hasPlaybackInfo = false
    var shouldStartTrackPing = false
    var lastBitRate: Float? = 0
    var lastBandwidth: Float? = 0
    var serverAddress: String?
    var serverName: String?
    var sessionId: String?
    var observersAvailables = false
    var firstPlay: Bool = true
    var firstPlayRate: Bool = true
    var mediaInfoJson: JSON = []
    var originalBounds = CGRect.zero
    private var waitingTimer: Timer?
    var uniqueId = UIDevice.current.identifierForVendor!.uuidString
    var session: AVAudioSession = AVAudioSession.sharedInstance()
    open var isPlayerReady = false
    open var events = EventManager()
    open var player: AVPlayer?
    open var playerViewController: AVPlayerViewController?
    open var playerLayer: AVPlayerLayer?
    open var currentStringDuration: String?
    open var currentStringValue: String?
    open var timeSliderMaximumValue: Float? = 0
    open var timeSliderMinimunValue: Float? = 0
    open var currentTimeValue: Float? = 0
    open var dismissButton: UIButton?
    open var castButton: UIButton?
    private var logoUrl: String?
    public var customUIView: MediastreamCustomUIView?
    private var loadingUIView: MediastreamLoadingUIView?
    private var messagesUIView: MediastreamMessagesUIView?
    open var castUrl = ""
    open var mediaTitle = ""
    var timeObserverToken: Any?
    
    //Ads
    var contentPlayhead: IMAAVPlayerContentPlayhead?
    var adsLoader: IMAAdsLoader?
    var adsManager: IMAAdsManager?
    var adUrl: String?
    var hasAds = false
    
    //Statics
    public enum StaticUrl: String {
        case PRODUCTION = "https://platform-static.cdn.mdstrm.com"
        case DEV = "https://platform-devel.s-mdstrm.com"
    }
    
    public convenience init() {
        self.init(imageURL: nil)
        AssetPlaybackManager.sharedManager.delegate = self
        playBackgroundAudio()
        let mediastreamFramework = Bundle(for: MediastreamPlatformSDK.self)
        if let loadingUI = mediastreamFramework.loadNibNamed("MediastreamLoadingView", owner: self, options: nil)?.first as? MediastreamLoadingUIView {
            loadingUIView = loadingUI
            loadingUIView?.frame = self.view.bounds
            loadingUIView?.loadingIndicator.startAnimating()
            self.view.addSubview(loadingUIView!)
        }
    }
    
    init(imageURL: URL?) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open var currentTime: Double {
        get { return CMTimeGetSeconds((self.player?.currentTime())!) }
        set (val) {
            if self.player == nil {
                self.playerTime = val
            } else {
                let newTime = CMTimeMakeWithSeconds(val, 1)
                self.player?.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            }
        }
    }
    
    open var volume: Int {
        get { return Int((self.player?.volume)! * 100) }
        set (val) {
            if self.player != nil {
                self.player?.volume = Float(val)/100
                if(self.config?.customUI)! {
                    if self.player?.volume == 0.0 {
                        changeVolumeIcon(soundOn: false)
                        isMuted = true
                    }
                }
            } else {
                self.initVolume = val
            }
        }
    }
    
    open func clearWaitingCount() {
        self.waitingCount = 0
    }
    
    open func removeObservers() {
        if observersAvailables {
            observersAvailables = false
            self.player?.currentItem?.removeObserver(self, forKeyPath: "status")
            self.player?.currentItem?.removeObserver(self, forKeyPath: "duration")
            self.player?.removeObserver(self, forKeyPath: "currentItem.loadedTimeRanges")
            self.player?.removeObserver(self, forKeyPath: "rate")
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player!.currentItem)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemNewAccessLogEntry, object: self.player!.currentItem)
            NotificationCenter.default.removeObserver(self, name: ReachabilityChangedNotification, object: reachability)
        }
        removeTimeObserver()
    }
    
    open func releasePlayer() {
        removeObservers()
        self.events.removeListeners(eventNameToRemoveOrNil: nil)
        if self.player?.currentItem != nil {
            self.stop()
            AssetPlaybackManager.sharedManager.setAssetForPlayback(nil)
            playerViewController?.player = nil
            playerViewController = nil
            playerLayer?.player = nil
            playerLayer = nil
            self.playerViewController = nil
            self.playerLayer = nil
            self.player = nil
            self.tracker?.stopTrackPing()
            self.tracker = nil
        }
    }
    
    open func reloadAssets() {
        if self.player?.currentItem != nil {
            AssetPlaybackManager.sharedManager.setAssetForPlayback(nil)
            playerViewController?.player = nil
            playerViewController = nil
            if (self.config?.customUI)! {
                playerLayer?.player = nil
                playerLayer = nil
            }
        }
    }
    
    open func playBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error as NSError {
            NSLog("Error: \(error.localizedDescription)")
        }
    }
    
    open func getBandwidth() -> Double {
        if self.lastBandwidth != nil {
            return Double(self.lastBandwidth!)
        } else {
            return 0
        }
    }
    
    open func getBitrate() -> Int {
        if self.lastBitRate != nil {
            return Int(self.lastBitRate!)
        } else {
            return 0
        }
    }
    
    open func getCurrentPosition() -> Int {
        return Int(CMTimeGetSeconds(self.player!.currentTime()))
    }
    
    open func getDuration() -> Int {
        let duration = self.player!.currentItem!.asset.duration.seconds
        if (duration.isNaN) {
            return getLiveDuration()
        } else {
            return Int(duration)
        }
    }
    
    open func getLiveDuration() -> Int {
        var result: Int = 0
        if let items = self.player?.currentItem?.seekableTimeRanges {
            if !items.isEmpty {
                let range = items[items.count - 1]
                let timeRange = range.timeRangeValue
                let startSeconds = CMTimeGetSeconds(timeRange.start)
                let durationSeconds = CMTimeGetSeconds(timeRange.duration)
                
                result = Int(startSeconds + durationSeconds)
            }
        }
        return result
    }
    
    open func getHeight() -> Int {
        let height = Int((self.player?.currentItem?.presentationSize.height)!)
        return height
    }
    
    open func getHostname() -> String {
        return self.serverName!
    }
    
    open func getUniqueId() -> String {
        return self.uniqueId
    }
    
    open func getSessionID() -> String {
        return self.sessionId!
    }
    
    open func getWaitingCount() -> Int {
        return self.waitingCount
    }
    
    open func play() {
        if self.player != nil {
            if self.hasAds {
                requestAds()
            } else {
                if self.isPlayerPlaying {
                    self.player?.pause()
                    if (self.config?.customUI)! {
                        changePlayButtonImage(pause: true)
                    }
                } else {
                    self.player?.play()
                    if (self.config?.customUI)! {
                        changePlayButtonImage(pause: false)
                    }
                }
            }
        } else {
            self.playRequest = true
        }
    }
    
    open func pause() {
        self.player!.pause()
    }
    
    open func stop() {
        self.pause()
    }
    
    open func seekTo(_ time: Double) {
        if self.playerTime == nil {
            self.playerTime = time
        } else {
            self.currentTime = time
        }
    }
    
    open func fordward(_ time: Double) {
        guard let duration = self.player?.currentItem?.duration else { return }
        let currentTime = CMTimeGetSeconds((self.player?.currentTime())!)
        let newTime = currentTime + time
        if newTime < (CMTimeGetSeconds(duration) - time) {
            let finalTime: CMTime = CMTimeMake(Int64(newTime*1000), 1000)
            self.player?.seek(to: finalTime)
        }
    }
    
    open func backward(_ time: Double) {
        let currentTime = CMTimeGetSeconds((self.player?.currentTime())!)
        var newTime = currentTime - time
        if newTime < 0 {
            newTime = 0
        }
        let finalTime: CMTime = CMTimeMake(Int64(newTime*1000), 1000)
        self.player?.seek(to: finalTime)
    }
    
    open func getTimeString(from time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        let hours = Int(totalSeconds/3600)
        let minutes = Int(totalSeconds/60) % 60
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return String(format: "%i:%02i:%02i", arguments: [hours, minutes, seconds])
        } else {
            return String(format: "%02i:%02i", arguments: [minutes, seconds])
        }
    }
    
    @objc open func contentDidFinishPlaying(_ notification: Notification) {
        if (notification.object as! AVPlayerItem) == self.player?.currentItem {
            self.events.trigger(eventName: "finish")
            if(adsLoader != nil) {
                adsLoader!.contentComplete()
            }
        }
    }
    
    @objc func handleAVPlayerAccess(_ notification: Notification) {
        if (notification.object as! AVPlayerItem) == self.player?.currentItem {
            let accessLog = (notification.object as! AVPlayerItem).accessLog()
            let lastEvent = accessLog?.events.last!
            let lastEventBitrate: Float = Float((lastEvent?.indicatedBitrate)!)
            let lastEventBandwidth: Float = Float((lastEvent?.observedBitrate)!)
            let serverAddress = lastEvent?.serverAddress
            var serverName = ""
            
            if lastEvent?.uri != nil {
                serverName = (URL(string: (lastEvent?.uri)!)?.host)!
            }
            if serverAddress != self.serverAddress {
                self.serverAddress = serverAddress
            }
            if serverName != self.serverName {
                self.serverName = serverName
            }
            if lastEventBitrate != self.lastBitRate {
                self.lastBitRate = lastEventBitrate
            }
            if lastEventBandwidth != self.lastBandwidth {
                self.lastBandwidth = lastEventBandwidth
            }
            if self.shouldStartTrackPing && self.isPlayerPlaying {
                self.tracker?.startTrackPing()
            }
            
            self.shouldStartTrackPing = false
            self.hasPlaybackInfo = true
        }
    }
    
    @objc func internetChange(note: Notification) {
        let reachability = note.object as! MediastreamPlayerReachability
        if reachability.isReachable {
            self.events.trigger(eventName: "conectionStablished")
        } else {
            self.events.trigger(eventName: "conectionLost")
        }
    }
    
    @objc func increaseWaitingCount() {
        self.waitingCount += 1
    }
    
    open func adsLoader(_ loader: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        let adsRenderingSettings = IMAAdsRenderingSettings()
        adsRenderingSettings.webOpenerPresentingController = self
        adsManager?.initialize(with: adsRenderingSettings)
    }
    
    open func adsLoader(_ loader: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
        self.player?.play()
    }
    
    open func adsManager(_ adsManager: IMAAdsManager!, didReceive event: IMAAdEvent!) {
        if (event.type == IMAAdEventType.LOADED) {
            adsManager.start()
        }
    }
    
    open func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager!) {
        self.player?.pause()
    }
    
    open func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager!) {
        self.player?.play()
    }
    
    open func adsManager(_ adsManager: IMAAdsManager!, didReceive error: IMAAdError!) {
        self.player?.play()
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if self.player?.rate != 0 {
                self.events.trigger(eventName: "play")
                if self.firstPlayRate {
                    firstPlayRate = false
                    addTimeObserver()
                }
                self.isPlayerPlaying = true
                if self.hasPlaybackInfo {
                    self.tracker?.startTrackPing()
                } else {
                    self.shouldStartTrackPing = true
                }
                changePlayButtonImage(pause: false)
            } else {
                self.events.trigger(eventName: "pause")
                self.isPlayerPlaying = false
                self.tracker?.stopTrackPing()
                changePlayButtonImage(pause: true)
            }
            self.stopWaitingTimer()
        } else if keyPath == "status" {
            if self.player?.currentItem?.status == AVPlayerItemStatus.failed {
                self.events.trigger(eventName: "error", information: self.player?.currentItem?.errorLog().debugDescription)
                self.stopWaitingTimer()
                self.tracker?.stopTrackPing()
            }
            if self.player?.currentItem?.status == AVPlayerItemStatus.readyToPlay {
                self.tracker?.setCanPlayDate(canPlayDate: Date())
                if (config?.customUI)! {
                    customUIView?.bufferingIndicator.isHidden = true
                }
            }
        } else if keyPath == "playbackBufferEmpty" {
            if (config?.customUI)! {
                customUIView?.bufferingIndicator.isHidden = false
            }
            if !(self.waitingTimer?.isValid)! && self.waitingCount == 0 {
                self.waitingTimer = Timer.init(
                    timeInterval: TimeInterval(3),
                    target: self,
                    selector: #selector(MediastreamPlatformSDK.increaseWaitingCount),
                    userInfo: nil,
                    repeats: false
                )
            }
        } else if keyPath == "duration", let duration = player?.currentItem?.duration.seconds, duration > 0.0 {
            self.currentStringDuration = getTimeString(from: (self.player?.currentItem?.duration)!)
            self.events.trigger(eventName: "durationUpdated", information: self.currentStringDuration)
            if (config?.customUI)! && config?.type == MediastreamPlayerConfig.VideoTypes.VOD {
                customUIView?.duration.text = self.currentStringDuration
            }
        } else if keyPath == "currentItem.loadedTimeRanges" {
            if firstPlay {
                self.isPlayerReady = true
                self.events.trigger(eventName: "ready")
                self.playerViewController?.view.isHidden = false
                firstPlay = false
                if (config?.customUI)! {
                    customUIView?.isHidden = false
                    showUI(show: false)
                }
            }
        }
    }
    
    open func preparePlayer(player: AVPlayer) {
        self.player = player
        self.player?.currentItem?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(), context: nil)
        self.player?.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions(), context: nil)
        self.player?.currentItem?.addObserver(self, forKeyPath: "duration", options: [.new, .initial], context: nil)
        self.player?.addObserver(self, forKeyPath: "currentItem.loadedTimeRanges", options: .new, context: nil)
        let playerViewController = AVPlayerViewController()
        self.view.addSubview(playerViewController.view)
        self.addChildViewController(playerViewController)
        playerViewController.view.isHidden = true
        playerViewController.view.frame = self.view.bounds
        playerViewController.player = self.player
        self.playerViewController = playerViewController
        if (self.config?.customUI)! {
            NSLog("MediastreamPlatformSDK: Setting custom layout")
            playerViewController.showsPlaybackControls = false
            let mediastreamFramework = Bundle(for: MediastreamPlatformSDK.self)
            if let customUI = mediastreamFramework.loadNibNamed("MediastreamCustomView", owner: self, options: nil)?.first as? MediastreamCustomUIView {
                customUI.frame = (self.playerViewController?.view.bounds)!
                customUI.topLayout.backgroundColor = UIColor.black.withAlphaComponent(0.3)
                customUI.bottomLayout.backgroundColor = UIColor.black.withAlphaComponent(0.3)
                customUI.bufferingIndicator.isHidden = true
                customUI.slider.addTarget(self, action: #selector(customUISliderValueChanged), for: UIControlEvents.valueChanged)
                customUI.playButton.addTarget(self, action: #selector(customUIPlayButtonPressed(sender:)), for: .touchUpInside)
                customUI.backwardButton.addTarget(self, action: #selector(customUIBackwardButtonPressed(sender:)), for: .touchUpInside)
                customUI.volumeButton.addTarget(self, action: #selector(customUIVolumeButtonPressed(sender:)), for: .touchUpInside)
                customUI.fullscreenButton.addTarget(self, action: #selector(customUIFullscreenButtonPressed(sender:)), for: .touchUpInside)
                customUI.dismissButton.isHidden = !(self.config?.showDismissButton)!
                customUI.castButton.isHidden = !(self.config?.showCastButton)!
                if self.config?.type.rawValue == MediastreamPlayerConfig.VideoTypes.LIVE.rawValue {
                    if (self.config?.dvr)! && (self.config?.windowDvr)! > 0 {
                        customUI.duration.isHidden = true
                        customUI.dvrLiveButton.isHidden = false
                        customUI.dvrLiveButton.addTarget(self, action: #selector(customdvrLiveButtonPressed(sender:)), for: .touchUpInside)
                    } else {
                        customUI.volumeButton.frame.origin = customUI.backwardButton.frame.origin
                        customUI.backwardButton.isHidden = true
                        customUI.slider.isHidden = true
                        customUI.currentTime.isHidden = true
                        customUI.duration.isHidden = true
                        customUI.dvrLiveButton.isHidden = true
                    }
                    if mediaInfoJson["show_status"] != JSON.null {
                        customUI.liveStatus.isHidden = !mediaInfoJson["show_status"].boolValue
                        if !(config?.showDismissButton)! {
                            customUI.liveStatus.frame.origin = customUI.dismissButton.frame.origin
                            customUI.title.frame.origin.x = customUI.liveStatus.bounds.width + 20
                            customUI.title.frame.origin.y = customUI.title.frame.origin.y + 5
                        }
                    }
                } else {
                    customUI.dvrLiveButton.isHidden = true
                    customUI.liveStatus.isHidden = true
                }
                self.dismissButton = customUI.dismissButton
                self.castButton = customUI.castButton
                if mediaInfoJson["show_title"] != JSON.null {
                    if mediaInfoJson["show_title"] == true {
                        customUI.title.text = mediaInfoJson["title"].string
                        customUI.title.numberOfLines = 0
                        customUI.title.sizeToFit()
                    } else {
                        customUI.title.isHidden = true
                    }
                }
                
                if mediaInfoJson["player"] != JSON.null {
                    if mediaInfoJson["player"]["base_color"] != JSON.null {
                        let themeColor = hexStringToUIColor(hex: mediaInfoJson["player"]["base_color"].string!)
                        customUI.slider.tintColor = themeColor
                        customUI.slider.thumbTintColor = themeColor
                    } else {
                        customUI.slider.tintColor = hexStringToUIColor(hex: "#97D700")
                        customUI.slider.thumbTintColor = hexStringToUIColor(hex: "#97D700")
                    }
                    if mediaInfoJson["player"]["logo"] != JSON.null {
                        if mediaInfoJson["player"]["logo"]["enabled"] == true {
                            if mediaInfoJson["player"]["logo"]["url"] != JSON.null  {
                                logoUrl = mediaInfoJson["player"]["logo"]["url"].string
                            }
                            if mediaInfoJson["player"]["logo"]["position"] == "control-bar" {
                                if (self.config?.environment == MediastreamPlayerConfig.Environments.DEV) {
                                    customUI.logoControlBar.downloadedFrom(url: URL(string: StaticUrl.DEV.rawValue + "/player/logo/" + mediaInfoJson["player"]["_id"].string! + ".png")!)
                                } else {
                                    customUI.logoControlBar.downloadedFrom(url: URL(string: StaticUrl.PRODUCTION.rawValue + "/player/logo/" + mediaInfoJson["player"]["_id"].string! + ".png")!)
                                }
                                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(customLogoGoToUrl(tapGestureRecognizer:)))
                                customUI.logoControlBar.isUserInteractionEnabled = true
                                customUI.logoControlBar.addGestureRecognizer(tapGestureRecognizer)
                                customUI.logoControlBar.isHidden = false
                            } else {
                                customUI.logoControlBar.isHidden = true
                                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(customLogoGoToUrl(tapGestureRecognizer:)))
                                switch mediaInfoJson["player"]["logo"]["position"].string {
                                case "top-right":
                                    customUI.topRightLogo.isHidden = false
                                    customUI.topLeftLogo.isHidden = true
                                    customUI.bottomLeftLogo.isHidden = true
                                    customUI.bottomRightLogo.isHidden = true
                                    setLogoImage(image: customUI.topRightLogo)
                                    customUI.topRightLogo.isUserInteractionEnabled = true
                                    customUI.topRightLogo.addGestureRecognizer(tapGestureRecognizer)
                                case "top-left":
                                    customUI.topRightLogo.isHidden = true
                                    customUI.topLeftLogo.isHidden = false
                                    customUI.bottomLeftLogo.isHidden = true
                                    customUI.bottomRightLogo.isHidden = true
                                    setLogoImage(image: customUI.topLeftLogo)
                                    customUI.topLeftLogo.isUserInteractionEnabled = true
                                    customUI.topLeftLogo.addGestureRecognizer(tapGestureRecognizer)
                                case "bottom-right":
                                    customUI.topRightLogo.isHidden = true
                                    customUI.topLeftLogo.isHidden = true
                                    customUI.bottomLeftLogo.isHidden = true
                                    customUI.bottomRightLogo.isHidden = false
                                    setLogoImage(image: customUI.bottomRightLogo)
                                    customUI.bottomRightLogo.isUserInteractionEnabled = true
                                    customUI.bottomRightLogo.addGestureRecognizer(tapGestureRecognizer)
                                case "bottom-left":
                                    customUI.topRightLogo.isHidden = true
                                    customUI.topLeftLogo.isHidden = true
                                    customUI.bottomLeftLogo.isHidden = false
                                    customUI.bottomRightLogo.isHidden = true
                                    setLogoImage(image: customUI.bottomLeftLogo)
                                    customUI.bottomLeftLogo.isUserInteractionEnabled = true
                                    customUI.bottomLeftLogo.addGestureRecognizer(tapGestureRecognizer)
                                default:
                                    customUI.topRightLogo.isHidden = true
                                    customUI.topLeftLogo.isHidden = true
                                    customUI.bottomLeftLogo.isHidden = true
                                    customUI.bottomRightLogo.isHidden = true
                                }
                            }
                        } else {
                            customUI.fullscreenButton.frame.origin = customUI.logoControlBar.frame.origin
                            customUI.logoControlBar.isHidden = true
                        }
                    }
                } else {
                    customUI.slider.tintColor = hexStringToUIColor(hex: "#97D700")
                    customUI.slider.thumbTintColor = hexStringToUIColor(hex: "#97D700")
                }
                customUIView = customUI
                if customUIView != nil {
                    let gesture = UITapGestureRecognizer(target: self, action:  #selector(self.checkAction))
                    customUIView?.addGestureRecognizer(gesture)
                    self.view.addSubview(customUIView!)
                    customUIView?.isHidden = true
                }
            }
            if self.config?.defaultOrientation != nil {
                UIDevice.current.setValue(self.config?.defaultOrientation?.rawValue, forKey: "orientation")
            }
        } else {
            NSLog("MediastreamPlatformSDK: Setting native layout")
            playerViewController.showsPlaybackControls = (self.config?.showControls)!
        }
        self.contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: self.player!)
        NotificationCenter.default.addObserver(self, selector: #selector(MediastreamPlatformSDK.contentDidFinishPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player!.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(MediastreamPlatformSDK.handleAVPlayerAccess(_:)), name: NSNotification.Name.AVPlayerItemNewAccessLogEntry, object: self.player!.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(internetChange), name: ReachabilityChangedNotification, object: reachability)
        
        do {
            try reachability?.startNotifier()
        } catch {
            print("Could not start notifier")
        }
        
        self.tracker = MediastreamPlayerTracker(config: self.config!, SDK: self)
        
        if self.initVolume != nil {
            self.volume = self.initVolume!
        }
        
        if self.playerTime != nil {
            let newTime = CMTimeMakeWithSeconds(self.playerTime!, 1)
            self.player?.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
        
        if self.playRequest || (self.config?.autoplay)! {
            self.play()
        }
        observersAvailables = true
    }
    
    open func setup(_ config: MediastreamPlayerConfig) {
        originalBounds = view.frame
        self.config = config
        if config.src != nil {
            self.player = AVPlayer(url: NSURL(fileURLWithPath: config.src!) as URL)
            preparePlayer(player: self.player!)
        } else {
            adsLoader = IMAAdsLoader(settings: nil)
            adsLoader?.delegate = self as IMAAdsLoaderDelegate
            
            let mediastreamFramework = Bundle(for: MediastreamPlatformSDK.self)
            if let messagesUI = mediastreamFramework.loadNibNamed("MediastreamMessagesView", owner: self, options: nil)?.first as? MediastreamMessagesUIView {
                messagesUIView = messagesUI
                messagesUIView?.frame = self.view.bounds
                self.view.addSubview(messagesUIView!)
                messagesUIView?.isHidden = true
            }
            
            let mediaInfoUrl = "\(config.environment.rawValue)/\(config.type.rawValue)/\(String(describing: config.id!)).json"
            DispatchQueue.main.async {
                RestApiManager.sharedInstance.getJSON(mediaInfoUrl) { (mediaInfo) in
                    if mediaInfo["status"] != JSON.null && mediaInfo["status"] == "ERROR" {
                        self.events.trigger(eventName: "error", information: mediaInfo["data"].string)
                        if mediaInfo["message"] != JSON.null {
                            self.setErrorMessage(message: mediaInfo["message"].string!)
                        } else {
                            self.setErrorMessage(message: "Error")
                        }
                        return
                    }
                    self.mediaInfoJson = mediaInfo
                    if mediaInfo["src"] != JSON.null {
                        let sessionURL = "https://mdstrm.com/api/session"
                        RestApiManager.sharedInstance.makeHTTPGetRequest(sessionURL, onCompletion: { json, cookies, err in
                            for cookie in cookies {
                                if cookie.name == "MDSTRMUID" {
                                    if config.debug {
                                        NSLog("MediastreamPlatformSDK: UniqueID setted to: \(cookie.value)")
                                    }
                                    self.uniqueId = cookie.value
                                }
                                if cookie.name == "MDSTRMSID" {
                                    if config.debug {
                                        NSLog("MediastreamPlatformSDK: SessionID setted to: \(cookie.value)")
                                    }
                                    self.sessionId = cookie.value
                                }
                            }
                            
                            var resourceUrl = mediaInfo["src"]["hls"].string!
                            resourceUrl += config.getMediaQueryString()
                            
                            if mediaInfo["src"]["mp4"] != JSON.null {
                                self.castUrl = mediaInfo["src"]["mp4"].string!
                                self.castUrl += config.getMediaQueryString()
                            }
                            
                            if mediaInfo["ads"]["map"] != JSON.null {
                                self.hasAds = true
                                self.adUrl = mediaInfo["ads"]["map"].string! + config.getAdQueryString()
                            }
                            
                            if config.hasAds() {
                                self.hasAds = true
                                self.adUrl = config.adURL
                            }
                            
                            AssetLoaderDelegate.playerConfig = config
                            let assetUrl = AVURLAsset(url: URL(string: resourceUrl)!)
                            let assetTitle = mediaInfo["title"].string
                            self.mediaTitle = mediaInfo["title"].string!
                            let asset = Asset(name: assetTitle!, urlAsset: assetUrl, resourceLoaderDelegate: AssetLoaderDelegate(asset: assetUrl, assetName: assetTitle!))
                            AssetPlaybackManager.sharedManager.setAssetForPlayback(asset)
                        })
                    }
                }
            }
        }
    }
    
    @objc open func showCastButton(show: Bool) {
        if(show) {
            self.customUIView?.castButton.isHidden = false
        } else {
            self.customUIView?.castButton.isHidden = true
        }
    }
    
    @objc func setErrorMessage(message: String) {
        DispatchQueue.main.async {
            self.messagesUIView?.isHidden = false
            self.messagesUIView?.message.text = message
        }
    }
    
    @objc func checkAction(sender : UITapGestureRecognizer) {
        showUI(show: isShowingUI)
        isShowingUI = !isShowingUI
    }
    
    func showUI(show: Bool) {
        if(self.isShowingUI) {
            return
        }
        if (self.config?.customUI)! {
            if customUIView != nil {
                customUIView?.topLayout.isHidden = show
                customUIView?.bottomLayout.isHidden = show
                self.isShowingUI = true;
                if !show && !isWaiting {
                    isWaiting = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showUI(show: true)
                        self.isShowingUI = false
                        self.isWaiting = false
                    }
                }
            }
        }
    }
    
    @objc func customUIPlayButtonPressed (sender: UIButton) {
        self.play()
    }
    
    @objc func customUIBackwardButtonPressed (sender: UIButton) {
        self.backward(10)
    }
    
    @objc func customdvrLiveButtonPressed(sender: UIButton) {
        self.seekTo(Double(getLiveDuration()))
    }
    
    @objc func customUIVolumeButtonPressed (sender: UIButton) {
        if isMuted {
            setVolume(volume: 100)
        } else {
            setVolume(volume: 0)
        }
    }
    
    @objc func customUIFullscreenButtonPressed (sender: UIButton) {
        if isFullscreen {
            changeFullscreenIcon(isFullscreen: false)
            isFullscreen = false
            enterFullscreen(fullscreen: false)
        } else {
            changeFullscreenIcon(isFullscreen: true)
            isFullscreen = true
            enterFullscreen(fullscreen: true)
        }
    }
    
    func enterFullscreen(fullscreen: Bool) {
        if(fullscreen) {
            self.originalBounds = (view.superview?.bounds)!
            view.superview?.bounds = UIScreen.main.bounds
            self.events.trigger(eventName: "onFullscreen")
        } else {
            view.superview?.bounds = self.originalBounds
            self.events.trigger(eventName: "offFullscreen")
        }
    }
    
    func setVolume(volume: Int) {
        if(self.player != nil) {
            if volume <= 0 {
                changeVolumeIcon(soundOn: false)
                isMuted = true
            } else {
                changeVolumeIcon(soundOn: true)
                isMuted = false
            }
            self.player?.volume = Float(volume)/100
        }
    }
    
    func changePlayButtonImage(pause: Bool) {
        if !(self.config?.customUI)! {
            return
        }
        
        let mediastreamFramework = Bundle(for: MediastreamPlatformSDK.self)
        if(pause) {
            guard let image = UIImage(named: "icon-play.png", in: mediastreamFramework, compatibleWith: nil) else {
                fatalError("Missing ic-play")
            }
            self.customUIView?.playButton.setImage(image, for: .normal)
        } else {
            guard let image = UIImage(named: "icon-pause.png", in: mediastreamFramework, compatibleWith: nil) else {
                fatalError("Missing ic-pause")
            }
            self.customUIView?.playButton.setImage(image, for: .normal)
        }
    }
    
    func changeVolumeIcon(soundOn: Bool) {
        let mediastreamFramework = Bundle(for: MediastreamPlatformSDK.self)
        if(soundOn) {
            guard let image = UIImage(named: "icon-volume-high.png", in: mediastreamFramework, compatibleWith: nil) else {
                fatalError("Missing icon-volume-high.png")
            }
            self.customUIView?.volumeButton.setImage(image, for: .normal)
        } else {
            guard let image = UIImage(named: "icon-volume-mute.png", in: mediastreamFramework, compatibleWith: nil) else {
                fatalError("Missing icon-volume-mute")
            }
            self.customUIView?.volumeButton.setImage(image, for: .normal)
        }
    }
    
    func changeFullscreenIcon(isFullscreen: Bool) {
        let mediastreamFramework = Bundle(for: MediastreamPlatformSDK.self)
        if(isFullscreen) {
            guard let image = UIImage(named: "icon-out-full-screen.png", in: mediastreamFramework, compatibleWith: nil) else {
                fatalError("Missing icon-out-full-screen.png")
            }
            self.customUIView?.fullscreenButton.setImage(image, for: .normal)
        } else {
            guard let image = UIImage(named: "icon-full-screen.png", in: mediastreamFramework, compatibleWith: nil) else {
                fatalError("Missing icon-full-screen")
            }
            self.customUIView?.fullscreenButton.setImage(image, for: .normal)
        }
    }
    
    func setLogoImage(image: UIImageView) {
        if (self.config?.environment == MediastreamPlayerConfig.Environments.DEV) {
            image.downloadedFrom(url: URL(string: StaticUrl.DEV.rawValue + "/player/logo/" + mediaInfoJson["player"]["_id"].string! + ".png")!)
        } else {
            image.downloadedFrom(url: URL(string: StaticUrl.PRODUCTION.rawValue + "/player/logo/" + mediaInfoJson["player"]["_id"].string! + ".png")!)
        }
        
    }
    
    func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let mainQueue = DispatchQueue.main
        timeObserverToken = self.player?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue, using: {[weak self] time in
            guard let currentItem = self?.player?.currentItem else { return }
            if self?.config?.type == MediastreamPlayerConfig.VideoTypes.LIVE {
                self?.timeSliderMaximumValue = Float((self?.getLiveDuration())!)
            } else {
                self?.timeSliderMaximumValue = Float(currentItem.asset.duration.seconds)
            }
            self?.timeSliderMinimunValue = 0
            self?.currentStringValue = self?.getTimeString(from: currentItem.currentTime())
            self?.currentTimeValue = Float(currentItem.currentTime().seconds)
            if (self?.config?.customUI)! && self?.config?.type == MediastreamPlayerConfig.VideoTypes.VOD {
                self?.customUIView?.currentTime.text = self?.currentStringValue
                self?.customUIView?.slider.maximumValue = (self?.timeSliderMaximumValue)!
                self?.customUIView?.slider.minimumValue = (self?.timeSliderMinimunValue)!
                self?.customUIView?.slider.value = (self?.currentTimeValue)!
            } else if (self?.config?.customUI)! && self?.config?.type == MediastreamPlayerConfig.VideoTypes.LIVE && (self?.config?.dvr)! && (self?.config?.windowDvr)! > 0 {
                self?.customUIView?.currentTime.text = self?.currentStringValue
                self?.customUIView?.slider.maximumValue = (self?.timeSliderMaximumValue)!
                self?.customUIView?.slider.minimumValue = (self?.timeSliderMinimunValue)!
                self?.customUIView?.slider.value = (self?.currentTimeValue)!
            }
            self?.events.trigger(eventName: "currentTimeUpdate", information: self?.currentStringValue)
        })
    }
    
    func removeTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            self.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    @objc func customUISliderValueChanged(sender: UISlider) {
        self.player?.seek(to: CMTimeMake(Int64(sender.value*1000), 1000))
    }
    
    @objc func customLogoGoToUrl(tapGestureRecognizer: UITapGestureRecognizer) {
        if self.logoUrl != nil {
            if let url = URL(string: self.logoUrl!) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: [:])
                } else {
                    // Fallback on earlier versions
                }
            }
        }
    }
    
    func stopWaitingTimer() {
        self.waitingTimer?.invalidate()
    }
    
    func requestAds() {
        let adDisplayContainer = IMAAdDisplayContainer(adContainer: self.view, companionSlots: nil)
        let request = IMAAdsRequest(adTagUrl: self.adUrl, adDisplayContainer: adDisplayContainer, contentPlayhead: contentPlayhead, userContext: nil)
        adsLoader?.requestAds(with: request)
        if firstPlay {
            hasAds = false
        }
    }
    
    func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

extension MediastreamPlatformSDK: AssetPlaybackDelegate {
    func streamPlaybackManager(_ streamPlaybackManager: AssetPlaybackManager, playerReadyToPlay player: AVPlayer) {
        self.preparePlayer(player: player)
    }
    
    func streamPlaybackManager(_ streamPlaybackManager: AssetPlaybackManager, playerCurrentItemDidChange player: AVPlayer) {
        if !(self.config?.customUI)! {
            guard let playerViewController = playerViewController , player.currentItem != nil else { return }
            playerViewController.player = player
        }
    }
}

extension UIImageView {
    func downloadedFrom(url: URL, contentMode mode: UIViewContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else { return }
            DispatchQueue.main.async() {
                self.image = image
            }
            }.resume()
    }
    func downloadedFrom(link: String, contentMode mode: UIViewContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloadedFrom(url: url, contentMode: mode)
    }
}
