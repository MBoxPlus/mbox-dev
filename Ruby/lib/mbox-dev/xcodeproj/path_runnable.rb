module Xcodeproj
  class XCScheme
    class PathRunnable < XMLElementWrapper
      # @param [REXML::Element] node
      #        an existing XML 'BuildableProductRunnable' node element to reference
      #        or nil to create an new, empty BuildableProductRunnable
      #
      # @param [#to_s] runnable_debugging_mode
      #        The debugging mode (usually '0')
      #
      def initialize(node, runnable_debugging_mode = nil)
        create_xml_element_with_fallback(node, 'PathRunnable') do
          @xml_element.attributes['runnableDebuggingMode'] = runnable_debugging_mode.to_s if runnable_debugging_mode
        end
      end

      # @return [String]
      #         The Runnable debugging mode (usually either empty or equal to '0')
      #
      def runnable_debugging_mode
        @xml_element.attributes['runnableDebuggingMode']
      end

      # @param [String] value
      #        Set the runnable debugging mode of this buildable product runnable
      #
      def runnable_debugging_mode=(value)
        @xml_element.attributes['runnableDebuggingMode'] = value.to_s
      end

      # @return [String]
      #         The Runnable file path
      #
      def file_path
        @xml_element.attributes['FilePath']
      end

      # @param [String, Pathname] value
      #        Set the file path of this path runnable
      #
      def file_path=(value)
        @xml_element.attributes['FilePath'] = value.to_s
      end
    end
  end
end
