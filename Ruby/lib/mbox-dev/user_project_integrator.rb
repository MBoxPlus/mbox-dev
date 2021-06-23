module Xcodeproj
  class XCScheme
    class XMLFormatter < REXML::Formatters::Pretty
      def write_element(node, output)
        @indentation = 3
        output << ' ' * @level
        output << "<#{node.expanded_name}"

        @level += @indentation
        node.context = node.parent.context # HACK: to ensure strings are properly quoted
        node.attributes.each_attribute do |attr|
          output << "\n"
          output << ' ' * @level
          output << attr.to_string.sub(/=/, ' = ').gsub(/\n/, '&#10;')
        end unless node.attributes.empty?

        output << '>'

        output << "\n"
        node.children.each do |child|
          next if child.is_a?(REXML::Text) && child.to_s.strip.length == 0
          write(child, output)
          output << "\n"
        end
        @level -= @indentation
        output << ' ' * @level
        output << "</#{node.expanded_name}>"
      end
    end
    class BuildAction
      class ExecutionAction < XMLElementWrapper
        def initialize(target_or_node = nil)
          create_xml_element_with_fallback(target_or_node, 'ExecutionAction') do
            @xml_element.attributes['ActionType'] = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"
            @action_content = @xml_element.add_element('ActionContent')
          end
        end
        def title
          @action_content.attributes['title']
        end
        def title=(title)
          @action_content.attributes['title'] = title
        end
        def scriptText
          @action_content.attributes['scriptText']
        end
        def scriptText=(scriptText)
          @action_content.attributes['scriptText'] = scriptText
        end
        def shellToInvoke
          @action_content.attributes['shellToInvoke']
        end
        def shellToInvoke=(shellToInvoke)
          @action_content.attributes['shellToInvoke'] = shellToInvoke
        end
        def build_setting_provider=(provider)
          @action_content.delete_element('EnvironmentBuildable')
          unless provider.nil?
            element = @action_content.add_element('EnvironmentBuildable')
            element.add_element(provider.xml_element)
          end
        end
      end

      def clear_entries
        @xml_element.elements.delete_all('BuildActionEntries')
      end

      def post_actions
        actions = @xml_element.elements['PostActions']
        return nil unless actions
        actions.get_elements('ExecutionAction').map do |action_node|
          BuildAction::ExecutionAction.new(action_node)
        end
      end

      def post_actions=(actions)
        @xml_element.delete_element('PostActions')
        unless actions.empty?
          actions_element = @xml_element.add_element('PostActions')
          actions.each do |action_node|
            actions_element.add_element(action_node.xml_element)
          end
        end
        actions
      end

      def add_post_action(action)
        actions = @xml_element.elements['PostActions'] || @xml_element.add_element('PostActions')
        actions.add_element(action.xml_element)
      end
    end
    class TestAction
      def clear_entries
        @xml_element.elements.delete_all('Testables')
      end
    end
    class BuildableReference
      def container_path
        container = @xml_element.attributes['ReferencedContainer']
        container.sub(/.*?:/, "") if container
      end

      def container_path=(path)
        @xml_element.attributes['ReferencedContainer'] = "container:#{path}"
      end
    end
  end
end

require_relative "xcodeproj/launch_action.rb"

module Pod
  class Installer
    class UserProjectIntegrator

      alias_method :mbox_dev_integrate_1202!, :integrate!
      def integrate!
        if ENV['DISABLE_AUTO_XCWORKSPACE']
          mbox_dev_integrate_1202!
          setup_mbox_scheme
        else
          opened = xcworkspace_open?
          close_xcworkspace if opened
          mbox_dev_integrate_1202!
          setup_mbox_scheme
          open_xcworkspace if opened
        end
      end

      extend Executable
      executable :osascript
      def apple_script(script)
        osascript script.split(/\n/).map { |line| ['-e', line.strip] }.flatten
      end

      def xcworkspace_open?
        UI.message("Check workspace is opened?") do
          names = apple_script <<-END
tell application "Xcode"
  name of workspace documents
end tell
          END
          names.split(",").map(&:strip).include?(workspace_path.basename.to_s)
        end
      end

      def open_xcworkspace
        UI.message("Open #{workspace_path.basename}") do
          apple_script <<-END
tell application "Xcode"
  open "#{workspace_path}"
end tell
          END
        end
      end

      def close_xcworkspace
        UI.message("Close #{workspace_path.basename}") do
          apple_script <<-END
tell application "Xcode"
  set _workspace to workspace document "#{workspace_path.basename.to_s}"
  close _workspace
end tell
          END
        end
      end

      def setup_mbox_scheme
        workspace_scheme_dir = Xcodeproj::XCScheme.shared_data_dir(workspace_path)
        FileUtils.mkdir_p(workspace_scheme_dir)
        scheme_path = workspace_scheme_dir + "MBox.xcscheme"

      	scheme = Xcodeproj::XCScheme.new(scheme_path.exist? ? scheme_path : nil)
        scheme.build_action.clear_entries
        scheme.test_action.clear_entries
        user_targets = user_projects.flat_map(&:native_targets).uniq.sort_by(&:name)
        user_targets.each do |user_target|
        	if user_target.test_target_type?
            entry = Xcodeproj::XCScheme::TestAction::TestableReference.new(user_target).tap do |entry|
              # 更新相对路径，Xcodeproj 不支持直接设置路径
              path = user_target.project.path.relative_path_from(workspace_path.dirname)
              ref = entry.buildable_references.first
              ref.set_reference_target(user_target)
              ref.container_path = path
            end
            scheme.test_action.add_testable(entry)
          else
            entry = Xcodeproj::XCScheme::BuildAction::Entry.new(user_target).tap do |entry|
              entry.build_for_testing = true
              entry.build_for_running = true
              entry.build_for_profiling = true
              entry.build_for_archiving = true
              entry.build_for_analyzing = true
              # 更新相对路径，Xcodeproj 不支持直接设置路径
              path = user_target.project.path.relative_path_from(workspace_path.dirname)
              ref = entry.buildable_references.first
              ref.set_reference_target(user_target)
              ref.container_path = path
            end
            scheme.build_action.add_entry(entry)
          end
      	end

        # 设置 Executable
        cli_target = user_projects.flat_map(&:native_targets).find { |target| target.name == ::Pod::Config.instance.mdev_cli_name }
        if cli_target
          # MDevCLI 为当前开发项目
          cli_ref = Xcodeproj::XCScheme::BuildableReference.new(cli_target)
          cli_ref.container_path = cli_target.project.path.relative_path_from(workspace_path.dirname)

          buildable_product_runnable = scheme.launch_action.buildable_product_runnable
          buildable_product_runnable.buildable_reference = cli_ref
          scheme.launch_action.buildable_product_runnable = buildable_product_runnable
        else
          # 使用 MBox.app 内的 MDevCLI
          path_runnable = scheme.launch_action.path_runnable
          path_runnable.file_path = ::Pod::Config.instance.mdev_cli_path
          scheme.launch_action.path_runnable = path_runnable
        end

        # 设置 Workspace/build 产物路径到参数
        args = scheme.launch_action.command_line_arguments
        args["--dev-root=#{::Pod::Config.instance.project_root}"] = true
        scheme.launch_action.command_line_arguments = args

        env = scheme.launch_action.environment_variables
        if env["DYLD_PRINT_LIBRARIES"].nil?
          env["DYLD_PRINT_LIBRARIES"] = "1"
          env["DYLD_PRINT_LIBRARIES"].enabled = false
        end
        if env["PATH"].nil?
          env["PATH"] = "$PATH:/usr/local/bin"
        end
        scheme.launch_action.environment_variables = env

      	if scheme_path.exist?
	      	scheme.save!
	      else
	      	scheme.save_as(workspace_path, "MBox")
	      end
      end
    end
  end
end