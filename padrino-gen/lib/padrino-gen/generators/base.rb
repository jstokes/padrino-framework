require 'thor'

module Padrino
  module Generators

    class Base < Thor::Group

      # Include related modules
      include Thor::Actions
      include Padrino::Generators::Actions

      class_option :root, :aliases => '-r', :default => nil, :type => :string

      def load_boot
        if in_app_root?(options[:root])
          require(options[:root] ? File.join(options[:root], 'config/boot.rb') : 'config/boot.rb')
        end
      end
    end

  end
end