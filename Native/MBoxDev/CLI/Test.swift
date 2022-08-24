//
//  Test.swift
//  MBoxDev
//
//  Created by Whirlwind on 2021/6/10.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxRuby

extension MBCommander.Plugin {
    open class Test: Plugin {

        open class override var description: String? {
            return "Test the native plugin(s)"
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("name", description: "Plugin/Module Names, otherwise will test all plugins.", required: false, plural: true)
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
            self.requireSetupEnvironment = true
        }

        open override func validate() throws {
            try super.validate()
            self.modules = self.developPlugins.flatMap { $0.allModules }
            if !self.names.isEmpty {
                self.modules = self.modules.filter { module in
                    return self.names.contains {
                        module.isName($0)
                    }
                }
            }
        }

        open var names: [String] = []
        open var file: String?
        open var method: String?
        open var modules: [MBPluginModule] = []

        open lazy var developPlugins: [MBPluginPackage] = {
            return self.config.currentFeature.repos.compactMap(\.workRepository).compactMap { MBPluginPackage.from(directory: $0.path) }
        }()

        open lazy var manager: MBPluginManager = {
            let manager = MBPluginManager()
            manager.allPackages = MBPluginManager.shared.allPackages
            for package in self.developPlugins {
                manager.allPackages.removeAll { $0.name == package.name }
                manager.allPackages.append(package)
            }
            return manager
        }()

        open override func run() throws {
            try super.run()
            UI.log(info: "Test Plugins:", items: self.modules.map { $0.name })
            try UI.log(verbose: "Check bundler environment") {
                try BundlerCMD.setup(workingDirectory: workspace.rootPath)
            }
            for module in self.modules {
                try UI.section("Test \(module.name)") {
                    let env = try self.setupEnv(name: module.name)
                    UI.log(info: env.toJSONString()!)
                    let cmd = BundlerCMD()
                    cmd.showOutput = true
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
                    if !cmd.exec("\(cmdString) -f '\(Self.pluginModule!.rubyDir!.appending(pathComponent: "rakefile"))'", env: env) {
                        throw UserError("[\(module.name)] Test Failed!")
                    }
                }
            }
        }

        open func setupTestCase(modules: [MBPluginModule]) throws -> [String] {
            return modules.map { module in
                return module.path.appending(pathComponent: "Native/Tests")
            }.filter { $0.isDirectory }
        }

        open func setupEnv(name: String) throws -> [String: String] {
            var env = [String: String]()
            var modules = manager.dependencies(for: name)
            if let module = manager.module(for: name) {
                modules.append(module)
            }
            env["MBOX_PLUGIN_PATHS"] = modules.map { $0.package.path }.withoutDuplicates().joined(separator: ":")
            env["MBOX_TEST_CASE_PATHS"] = try self.setupTestCase(modules: modules).joined(separator: ":")
            env["MBOX_TEST_PLUGIN_NAME"] = name
            if let devRoot = MBProcess.shared.devRoot {
                env["MBOX_DEV_ROOT"] = devRoot
            }
            return env
        }
    }
}
