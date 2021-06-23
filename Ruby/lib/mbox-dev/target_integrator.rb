
require 'cocoapods/target/aggregate_target'

class Object
  def redef_without_warning(const, value)
    mod = self.is_a?(Module) ? self : self.class
    mod.send(:remove_const, const) if mod.const_defined?(const)
    mod.const_set(const, value)
  end
end

module Pod
  class AggregateTarget
    redef_without_warning(:EMBED_FRAMEWORKS_IN_HOST_TARGET_TYPES, (EMBED_FRAMEWORKS_IN_HOST_TARGET_TYPES - [:framework]).freeze)
  end

  class Installer
    class UserProjectIntegrator
     class TargetIntegrator
       redef_without_warning(:EMBED_FRAMEWORK_TARGET_TYPES, (EMBED_FRAMEWORK_TARGET_TYPES + [:framework]).freeze)
     end
    end
  end
end
