//
//  Dev.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/8/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspace
import MBoxDependencyManager
import MBoxContainer

extension MBCommander.Plugin {
    open class Dev: Plugin {

        open class override var description: String? {
            return "Use a template to develop a MBox Plugin"
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("template", description: "Plugin Template.",
                                  values: Build.stages.map { $0.name },
                                  required: true)
            arguments << Argument("name", description: "Plugin Name (eg: MBoxCore)", required: false)
            return arguments
        }

        open override func setup() throws {
            templateName = try self.shiftArgument("template")
            self.name = self.shiftArgument("name")
            try super.setup()
            self.shouldUpdateWorkspaceFile = true
        }

        open var templateName: String = ""
        open var name: String?

        open func moduleName(with name: String) -> String {
            var name = name.convertCamelCased()
            if name.lowercased().hasPrefix("mbox") {
                name = "MBox" + name[4...]
            }
            if !name.hasPrefix("MBox") {
                name = "MBox" + name
                UI.log(warn: "MBox Plugin must has a prefix `MBox`, so we use the name `\(name)`.")
            }
            return name
        }

        open var template: DevTemplate.Type!
        open var installPath: String {
            return self.module.path.appending(pathComponent: template.dirName)
        }

        open var package: MBPluginPackage!
        open var module: MBPluginModule!

        dynamic
        open class var allTemplates: [DevTemplate.Type] {
            return [LauncherStage.self, ResourceStage.self, SettingStage.self]
        }

        open override func validate() throws {
            try super.validate()
            guard let workRepo = self.currentRepo?.workRepository else {
                throw UserError("Must run in a repo directory.")
            }

            guard let template = Self.allTemplates.first(where: { $0.name.lowercased() == templateName.lowercased() }) else {
                throw ArgumentError.invalidValue(value: templateName, argument: "template")
            }
            self.template = template

            var originName: String
            if let name = self.name {
                originName = name
            } else {
                let path: String
                if !template.supportSubmodule || FileManager.pwd == workRepo.path {
                    path = workRepo.path
                } else {
                    path = FileManager.pwd
                }
                if let module = MBPluginModule.load(fromFile: path.appending(pathComponent: "manifest.yml")) {
                    originName = module.name
                } else {
                    originName = path.relativePath(from: workRepo.path.deletingLastPathComponent)
                    if originName == "." {
                        originName = path.lastPathComponent
                    }
                }
            }
            self.name = self.moduleName(with: originName)

            self.package = workRepo.manifest ?? workRepo.createManifest(name: self.name!)

            if !self.name!.hasPrefix(self.package.name) {
                UI.log(error: "NAME(\(self.name!)) must be have a prefix `\(self.package.name)`.")
                throw ArgumentError.invalidValue(value: self.name!, argument: "name")
            }
            let root = workRepo.path.appending(pathComponent: self.name!.deletePrefix(self.package.name))
            self.module = try self.package.createModule(name: self.name!, root: root)

            if installPath.isExists {
                throw UserError("The directory `\(template.name)` exists!")
            }
            UI.log(info: "Create Plugin Module `\(name!)` with Template `\(self.template.name)`")
        }

        open override func run() throws {
            try super.run()
            try copyTemplate()
            try clean()
            try apply()
            try mergeSetting()
            try createMetadata()
            self.checkMBoxLatestVersion()

            try self.activateComponent()
            try self.activateContainer()

            self.config.save()
            UI.log(info: "Create Plugin `\(name!)` Success!")
        }

        open func copyTemplate() throws {
            try UI.section("Copy Template Files") {
                try self.template.copy(to: installPath)
            }
        }

        open func clean() throws {
            try UI.section("Clean Unused Files") {
                try self.template.cleanUnusedFiles(in: installPath)
            }
        }

        open func apply() throws {
            try UI.section("Apply Template String") {
                try self.template.apply(with: self.module, in: installPath)
            }
        }

        open func mergeSetting() throws {
            try UI.section("Merge `.mboxconfig`") {
                try self.template.mergeConfig(from: installPath.appending(pathComponent: ".mboxconfig"), target: self.workRepo)
            }
        }

        open func updateManifest() throws {
            try UI.section("Update `manifest.yml`") {
                try self.template.updateManifest(self.module!)
                self.module.save()
                self.module.superModule?.save()
            }
        }

        open func createMetadata() throws {
            try self.updateManifest()
            let readme = self.workRepo.path.appending(pathComponent: "README.md")
            if !readme.isExists {
                try UI.section("Create `README.md`") {
                    try "".write(toFile: readme, atomically: true, encoding: .utf8)
                }
            }
            let changelog = self.workRepo.path.appending(pathComponent: "CHANGELOG.md")
            if !changelog.isExists {
                try UI.section("Create `CHANGELOG.md`") {
                    try "".write(toFile: changelog, atomically: true, encoding: .utf8)
                }
            }
        }

        open func checkMBoxLatestVersion()  {
            if let latestVersion = MBoxCore.latestVersion {
                if let localVersion = Foundation.Bundle.app?.shortVersion, localVersion.isVersion(lessThan: latestVersion) {
                    UI.log(warn: "MBox (version: \(localVersion)) on your Mac is lower than the latest version: \(latestVersion).")
                }
            } else {
                UI.log(verbose: "Failed request latest version of MBox.")
            }
        }

        dynamic
        open func activateComponent() throws {
            guard let components = self.currentRepo?.workRepository?.components else {
                return
            }
            UI.section("Activate Components") {
                for component in components {
                    self.currentRepo?.activateComponent(component)
                }
            }
        }

        dynamic
        open func activateContainer() throws {
            if let containers = self.currentRepo?.workRepository?.containers {
                UI.section("Activate Containers") {
                    self.config.currentFeature.activateContainers(containers)
                }
            }
        }
    }
}
