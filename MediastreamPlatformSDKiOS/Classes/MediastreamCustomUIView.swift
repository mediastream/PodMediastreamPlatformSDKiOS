//
//  MediastreamCustomUIView.swift
//  MediastreamPlatformSDK
//
//  Created by Carlos Ruiz on 9/13/18.
//  Copyright © 2018 Mediastream. All rights reserved.
//

import UIKit

public class MediastreamCustomUIView: UIView {
    @IBOutlet weak open var topRightLogo: UIImageView!
    @IBOutlet weak open var topLeftLogo: UIImageView!
    @IBOutlet weak open var bottomLeftLogo: UIImageView!
    @IBOutlet weak open var bottomRightLogo: UIImageView!
    @IBOutlet weak open var topLayout: UIView!
    @IBOutlet weak open var bottomLayout: UIView!
    @IBOutlet weak open var dismissButton: UIButton!
    @IBOutlet weak open var liveStatus: UIButton!
    @IBOutlet weak open var title: UILabel!
    @IBOutlet weak var castButton: UIButton!
    @IBOutlet weak open var playButton: UIButton!
    @IBOutlet weak open var backwardButton: UIButton!
    @IBOutlet weak open var volumeButton: UIButton!
    @IBOutlet weak open var fullscreenButton: UIButton!
    @IBOutlet weak open var logoControlBar: UIImageView!
    @IBOutlet weak open var slider: UISlider!
    @IBOutlet weak open var currentTime: UILabel!
    @IBOutlet weak open var duration: UILabel!
    @IBOutlet weak open var dvrLiveButton: UIButton!
    @IBOutlet weak open var bufferingIndicator: UIActivityIndicatorView!
}
