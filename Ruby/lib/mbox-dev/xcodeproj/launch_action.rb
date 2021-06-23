
require_relative "path_runnable.rb"

module Xcodeproj
  class XCScheme
    class LaunchAction
      # @return [PathRunnable]
      #         The BuildReference to launch when executing the Launch Action
      #
      def path_runnable
        PathRunnable.new(@xml_element.elements['PathRunnable'], 0)
      end

      # @param [PathRunnable] runnable
      #        Set the PathRunnable referencing the target to launch
      #
      def path_runnable=(runnable)
        @xml_element.delete_element('PathRunnable')
        @xml_element.add_element(runnable.xml_element) if runnable
      end
    end
  end
end
