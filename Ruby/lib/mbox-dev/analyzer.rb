
module Pod
  class Installer
    class Analyzer
      alias_method :mbox_dev_dependencies_to_fetch_1201, :dependencies_to_fetch
      def dependencies_to_fetch(podfile_state)
        @deps_to_fetch ||= begin
          deps_to_fetch = mbox_dev_dependencies_to_fetch_1201(podfile_state)
          config.mbox_local_specifications.each do |name, dir|
            next if deps_to_fetch.find { |dep| dep.name == name }
            deps_to_fetch << Dependency.new(name, { :path => dir.to_s })
          end
          deps_to_fetch
        end
      end
    end
  end
end