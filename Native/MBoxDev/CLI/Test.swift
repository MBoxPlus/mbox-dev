//
//  Test.swift
//  MBoxDev
//
//  Created by Whirlwind on 2021/6/10.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore
import MBoxRuby

extension MBCommander.Plugin {
    open class Test: Plugin {

        open class override var description: String? {
            return "Test the native plugin(s)"
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("name", description: "Plugin Names, otherwise will test all plugins.", required: false, plural: true)
            return arguments
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("file", description: "Only run specific test file")
            options << Option("method", description: "Only run specific test method")
            return options
        }

        open override func setup() throws {
            self.file = self.shiftOption("file")
            self.method = self.shiftOption("method")
            self.names = self.shiftArguments("name")
            try super.setup()
        }

        open override func validate() throws {
            try super.validate()
            self.plugins = self.developPlugins
            if !self.names.isEmpty {
                self.plugins = self.plugins.filter { plugin in
                    return self.names.contains { plugin.isPlugin($0) }
                }
            }
        }

        open var names: [String] = []
        open var file: String?
        open var method: String?
        open var plugins: [MBPluginPackage] = []

        open lazy var developPlugins: [MBPluginPackage] = {
            return self.config.currentFeature.repos.compactMap(\.workRepository).compactMap { MBPluginPackage.from(directory: $0.path) }
        }()

        open lazy var manager: MBPluginManager = {
            let manager = MBPluginManager()
            manager.allPackages = MBPluginManager.shared.allPackages
            for package in self.developPlugins {
                manager.allPackages[package.name] = package
            }
            return manager
        }()

        open override func run() throws {
            try super.run()
            UI.log(info: "Test Plugins: \(self.plugins.map { $0.name })")
            try UI.log(verbose: "Check bundler environment") {
                try BundlerCMD.setup(workingDirectory: workspace.rootPath)
            }
            for plugin in self.plugins {
                try UI.section("Test \(plugin.name)") {
                    let env = try self.setupEnv(name: plugin.name)
                    UI.log(info: env.toJSONString()!)
                    let cmd = BundlerCMD(useTTY: true)
                    cmd.env = cmd.env.filter { item in
                        return !item.key.hasPrefix("MBOX_") ||
                            item.key == "MBOX_CLI_PATH"
                    }
                    var cmdString = "exec rake test"
                    if let file = self.file {
                        cmdString << " TEST='\(file)'"
                    }
                    if let method = self.method {
                        cmdString << " TESTOPTS='--name=\(method)'"
                    }
                    if !cmd.exec("\(cmdString) -f '\(Self.pluginPackage!.rubyDir!.appending(pathComponent: "rakefile"))'", env: env) {
                        throw UserError("[\(plugin.name)] Test Failed!")
                    }
                }
            }
        }

        open func setupTestCase(packages: [MBPluginPackage]) throws -> [String] {
            return packages.map { package in
                return package.path.appending(pathComponent: "Native/Tests")
            }.filter { $0.isDirectory }
        }

        open func setupEnv(name: String) throws -> [String: String] {
            var env = [String: String]()
            let packages = manager.dependencies(for: name)
            env["MBOX_PLUGIN_PATHS"] = packages.map { $0.path }.joined(separator: ":")
            env["MBOX_TEST_CASE_PATHS"] = try self.setupTestCase(packages: packages).joined(separator: ":")
            env["MBOX_TEST_PLUGIN_NAME"] = name
            if let devRoot = UI.devRoot {
                env["MBOX_DEV_ROOT"] = devRoot
            }
            return env
        }
    }
}
