//
//  NextVersion.swift
//  MBoxDev
//
//  Created by 詹迟晶 on 2019/11/19.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBCommander.Plugin {
    open class NextVersion: Plugin {
        open class override var description: String? {
            return "Increments the version numbers"
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("new-version", description: "Set a version instead of Increments.", required: false)
            return arguments
        }

        open override func setup() throws {
            try super.setup()
            self.version = self.shiftArgument("new-version")
        }

        open override func validate() throws {
            try super.validate()
            guard let repo = self.currentRepo?.workRepository else {
                throw UserError("Must run in a repo directory.")
            }
            if repo.manifest == nil {
                throw UserError("Require manifest.yml.")
            }
        }

        open var version: String?

        open override func run() throws {
            let repo = self.currentRepo!.workRepository!
            if let version = self.version {
                try UI.section("Update Major Version \(version)") {
                    try repo.updateMajorVersion(version)
                }
            }
            let nextVersion = try UI.section("Generate Next Version") { () -> String in
                let versions = try repo.nextVersion(force: true)!
                if let current = versions.current {
                    UI.log(info: "Update version \(versions.next) from \(current).")
                } else {
                    UI.log(info: "Update version \(versions.next).")
                }
                return versions.next
            }
            try UI.section("Update All Module Version") {
                for stageClass in Build.stages {
                    let stage = stageClass.init(outputDir: "")
                    if stage.shouldBuild(repo: repo) {
                        try stage.upgrade(repo: repo, nextVersion: nextVersion)
                    }
                }
            }
        }
    }
}

