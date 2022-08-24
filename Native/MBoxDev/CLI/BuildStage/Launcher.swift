//
//  Launcher.swift
//  MBoxDev
//
//  Created by Whirlwind on 2021/6/1.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

public class LauncherStage: BuildStage {
    public static var name: String {
        return "Launcher"
    }

    required public init(outputDir: String) {
        self.outputDir = outputDir
    }

    public var outputDir: String

    public func buildStep(for repo: MBWorkRepo) -> [BuildStep] {
        let sourcePath = repo.path.appending(pathComponent: "Launcher")
        if sourcePath.isExists { return [.build] }
        return []
    }

    public func build(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws {
        let sourcePath = repo.path.appending(pathComponent: "Launcher")
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

extension LauncherStage: DevTemplate {
    public static var path: String? {
        return MBoxDev.pluginPackage?.resoucePath(for: "Templates/Launcher")
    }

    public static var supportSubmodule: Bool {
        return false
    }

    public static func updateManifest(_ module: MBPluginModule) throws {
        guard let package = module as? MBPluginPackage else { return }
        package.hasLauncher = true
    }
}
