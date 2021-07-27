//
//  Launcher.swift
//  MBoxDev
//
//  Created by 詹迟晶 on 2021/6/1.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

public class LauncherStage: BuildStage {

    public static var name: String {
        return "Launcher"
    }

    required public init(outputDir: String) {
        self.outputDir = outputDir
    }

    public var outputDir: String

    public static var path: String? {
        return MBoxDev.pluginPackage?.resoucePath(for: "Templates/Launcher")
    }

    public static func updateManifest(_ manifest: MBPluginPackage) throws {
        manifest.hasLauncher = true
    }

    public func build(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
        for (repo, _, _) in repos {
            let sourcePath = repo.path.appending(pathComponent: "Launcher")
            guard sourcePath.isExists else { continue }
            var dstPath = repo.productDir(self.outputDir)
            if !dstPath.isDirectory {
                try FileManager.default.createDirectory(atPath: dstPath, withIntermediateDirectories: true)
            }
            dstPath = dstPath.appending(pathComponent: "Launcher")
            try UI.log(verbose: "Copy `\(Workspace.relativePath(sourcePath))` -> `\(Workspace.relativePath(dstPath))`.") {
                if dstPath.isExists {
                    try FileManager.default.removeItem(atPath: dstPath)
                }
                try FileManager.default.copyItem(atPath: sourcePath, toPath: dstPath)
            }
        }
    }
}
