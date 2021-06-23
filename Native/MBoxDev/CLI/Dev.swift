//
//  Dev.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/8/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore
import MBoxWorkspace

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

        open override func setup(argv: ArgumentParser) throws {
            try super.setup(argv: argv)
            templateName = try self.shiftArgument("template")
            name = (self.shiftArgument("name") ?? root.lastPathComponent.convertCamelCased())
            if name.lowercased().hasPrefix("mbox") {
                name = "MBox" + name[4...]
            }
            self.shouldUpdateWorkspaceFile = true
        }

        open var templateName: String = ""
        open var name: String = ""

        open var template: DevTemplate.Type!
        open lazy var root: String = FileManager.pwd
        open var installPath: String {
            return root.appending(pathComponent: template.dirName)
        }

        open override func validate() throws {
            try super.validate()
            if self.currentRepo?.workRepository == nil {
                throw UserError("Must run in a repo directory.")
            }
            guard let template = Build.stages.first(where: { $0.name.lowercased() == templateName.lowercased() }) else {
                throw ArgumentError.invalidValue(value: templateName, argument: "template")
            }
            self.template = template
            if installPath.isExists {
                throw UserError("The directory `\(template.name)` exists!")
            }
            if !name.hasPrefix("MBox") {
                name = "MBox" + name
                UI.log(warn: "MBox Plugin must has a prefix `MBox`, so we use the name `\(name)`.")
            }
            UI.log(info: "Create Plugin `\(name)` with Template `\(self.template.name)`")
        }

        open override func run() throws {
            try super.run()
            try copyTemplate()
            try clean()
            try apply()
            try mergeSetting()
            try createMetadata()
            self.checkMBoxLatestVersion()

            UI.log(info: "Create Plugin `\(name)` Success!")
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
            try UI.section("Apply Project Name") {
                try self.template.apply(with: name, in: installPath)
            }
        }

        open func mergeSetting() throws {
            try UI.section("Merge `.mboxconfig`") {
                try self.template.mergeConfig(from: installPath.appending(pathComponent: ".mboxconfig"), target: self.workRepo)
            }
        }

        open func updateManifest() throws {
            UI.section("Update `manifest.yml`") {
                let manifest = self.workRepo.manifest ?? self.workRepo.createManifest(name: self.name)
                self.template.updateManifest(manifest)
                manifest.save()
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
    }
}
