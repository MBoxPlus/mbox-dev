
module Pod
  module Generator
    class EmbedFrameworksScript
      alias_method :mbox_dev_script_0219, :script
      def script
        v = mbox_dev_script_0219
        v.gsub!('--filter "- Headers" --filter "- PrivateHeaders" --filter "- Modules" ', '')
        v.gsub!('--filter \"- Headers\" --filter \"- PrivateHeaders\" --filter \"- Modules\" ', '')
        v
      end
    end
  end
end
