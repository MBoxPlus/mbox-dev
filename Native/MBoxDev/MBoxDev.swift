//
//  MBoxDev.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/8/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

@objc(MBoxDev)
open class MBoxDev: NSObject, MBPluginProtocol {
    public func registerCommanders() {
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Dev.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.NextVersion.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Build.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Test.self)
    }
}
