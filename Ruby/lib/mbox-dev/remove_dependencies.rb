
module Pod
  class Installer
    class Analyzer
      alias_method :mbox_dev_dependencies_for_specs, :dependencies_for_specs
      def dependencies_for_specs(specs, platform, all_specs)
        dependent_specs = {
          :debug => Set.new,
          :release => Set.new,
        }

        if !specs.empty? && !all_specs.empty?
          specs.each do |s|
            s.dependencies(platform).each do |dep|
              # Hook to skip
              ss = all_specs[dep.name]
              next if ss.nil?
              ss.each do |spec|
                if spec.non_library_specification?
                  if s.test_specification? && spec.name == s.consumer(platform).app_host_name && spec.app_specification?
                    # This needs to be handled separately, since we _don't_ want to treat this as a "normal" dependency
                    next
                  end
                  raise Informative, "`#{s}` depends upon `#{spec}`, which is a `#{spec.spec_type}` spec."
                end

                dependent_specs.each do |config, set|
                  next unless s.dependency_whitelisted_for_configuration?(dep, config)
                  set << spec
                end
              end
            end
          end
        end

        Hash[dependent_specs.map { |k, v| [k, (v - specs).group_by(&:root)] }].freeze
      end
    end
  end

  class Resolver
    alias_method :mbox_dev_resolver_specs_by_target, :resolver_specs_by_target
    def resolver_specs_by_target
      dev_names = sandbox.development_pods.keys

      # 裁剪开发库的依赖
      @activated.vertices.each do |name, vertex|
        next unless dev_names.include?(vertex.payload.root.name)
        vertex.outgoing_edges.delete_if { |edge|
          !dev_names.include?(edge.destination.payload.root.name)
        }
      end

      # 筛选最小依赖树
      query_dependencies = @podfile_dependency_cache.podfile_dependencies.map(&:name).uniq
      require_dependencies = []
      while !query_dependencies.empty?
        name = query_dependencies.pop
        require_dependencies << name
        if vertex = @activated.vertices[name]
          vertex.outgoing_edges.map(&:destination).each do |dest|
            dest_name = dest.payload.root.name
            if !require_dependencies.include?(dest_name) && !query_dependencies.include?(dest_name)
              query_dependencies << dest_name
            end
          end
        end
      end

      # 根据最小依赖树移除不需要的依赖
      @activated.vertices.delete_if do |name, _|
        !require_dependencies.include?(name)
      end

      mbox_dev_resolver_specs_by_target
    end
  end
end