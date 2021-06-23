//
//  Plugin.swift
//  MBoxDev
//
//  Created by 詹迟晶 on 2021/3/23.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBCommander.Plugin {
    open var workRepo: MBWorkRepo {
        return self.currentRepo!.workRepository!
    }
}
