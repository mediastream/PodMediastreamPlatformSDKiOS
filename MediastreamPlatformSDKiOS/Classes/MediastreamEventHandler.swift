//
//  MediastreamEventHandler.swift
//  MediastreamPlatformSDK
//
//  Created by Adler Oliveira on 11/2/16.
//  Copyright © 2016 Mediastream. All rights reserved.
//

import Foundation

public protocol MediastreamEventHandler {
    func on(event: String, payload: Any)
}
