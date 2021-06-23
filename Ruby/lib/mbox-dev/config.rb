
module Pod
  class Config
    def mbox_application_path
      @mbox_application_path ||= Pathname.new("/Applications/MBox.app")
    end

    def mbox_plugins_path
      @mbox_plugins_path ||= (mbox_application_path + "Contents/Resources/Plugins")
    end

    def mdev_cli_name
      "MDevCLI"
    end

    def mdev_cli_path
      @mdev_cli_path ||= (mbox_plugins_path + "MBoxCore" + mdev_cli_name)
    end

  	def mbox_local_specifications
  		@mbox_local_specifications ||= begin
        Dir[mbox_plugins_path + "*/*.podspec.json"].map do |path|
          path = Pathname(path)
          name = path.basename('.podspec.json').to_s
          [name, path.dirname]
        end.to_h
  		end
  	end
  end
end
