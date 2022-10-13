//
//  Setting.swift
//  MBoxDev
//
//  Created by 詹迟晶 on 2021/9/29.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

public class SettingStage: BuildStage {

    public static var name: String {
        return "Setting"
    }

    required public init(outputDir: String) {
        self.outputDir = outputDir
    }

    public var outputDir: String

    public func buildStep(for repo: MBWorkRepo) -> [BuildStep] {
        let hasSettingFile = repo.manifest!.allModules.contains { $0.hasSettingFile }
        guard hasSettingFile else { return [] }
        return [.build]
    }

    public func build(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws {
        let productDir = repo.productDir(self.outputDir)

        for module in repo.manifest!.allModules {
            try module.copySettingFile(productDir)
        }
    }
}

extension SettingStage: DevTemplate {
    public static var path: String? { return nil }
}

extension MBPluginModule {
    public var hasSettingFile: Bool {
        let settingFile = self.path.appending(pathComponent: "setting.schema.json")
        return settingFile.isExists
    }

    public func copySettingFile(_ output: String) throws {
        let settingFile = self.path.appending(pathComponent: "setting.schema.json")
        guard settingFile.isExists else { return }
        try UI.log(verbose: "[\(self.name)]") {
            let dstPath = output.appending(pathComponent: self.relativeDir).appending(pathComponent: settingFile.lastPathComponent)
            if dstPath.isExists {
                try FileManager.default.removeItem(atPath: dstPath)
            }
            try UI.log(verbose: "Copy `\(Workspace.relativePath(settingFile))` -> `\(Workspace.relativePath(dstPath))`") {
                try FileManager.default.copyItem(atPath: settingFile, toPath: dstPath)
            }
        }
    }
}
