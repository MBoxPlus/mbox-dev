
module Pod
  class AggregateTarget
    alias_method :custom_initialize, :initialize
    def initialize(sandbox, build_type, user_build_configurations, archs, platform, target_definition, client_root,
                   user_project, user_target_uuids, pod_targets_for_build_configuration)
      pods = target_definition.dependencies.map(&:name)
      pod_targets_for_build_configuration.each do |name, pod_targets|
        pod_targets.delete_if { |target|
          d = (target.library_specs.map { |spec| spec.name } & pods).empty?
          #puts "delete #{target.name}" if d
          d
        }
      end
      custom_initialize(sandbox, build_type, user_build_configurations, archs, platform, target_definition, client_root,
        user_project, user_target_uuids, pod_targets_for_build_configuration)
    end
  end
end
