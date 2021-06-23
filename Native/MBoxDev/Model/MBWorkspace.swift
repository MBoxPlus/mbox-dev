//
//  MBWorkspace.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/9/7.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBWorkspace {
    public var releaseDirectory: String {
        return self.rootPath.appending(pathComponent: "release")
    }
}
