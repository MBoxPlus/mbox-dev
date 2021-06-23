
module Pod
  class Podfile
    alias_method :mbox_dev_initialize_1201, :initialize
    def initialize(defined_in_file = nil, internal_hash = {}, &block)
      mbox_dev_initialize_1201(defined_in_file, internal_hash) do
        source 'https://cdn.cocoapods.org/'
        platform :osx, '10.15'
        instance_eval(&block)
        install! 'cocoapods', :generate_multiple_pod_projects=>true, :incremental_installation=>true

        post_install do |installer|
          installer.generated_projects&.flat_map(&:targets).each do |target|
            target.build_configurations.each do |config|
              config.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
              config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
              config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
            end
          end
        end

      end
    end
  end
end
