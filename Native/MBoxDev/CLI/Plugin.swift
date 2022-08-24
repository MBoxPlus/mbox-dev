//
//  Plugin.swift
//  MBoxDev
//
//  Created by Whirlwind on 2021/3/23.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

extension MBCommander.Plugin {
    public var workRepo: MBWorkRepo {
        return self.currentRepo!.workRepository!
    }
}
