# frozen_string_literal: true

require 'erb'

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Install Karafka Cli action
    class Install < Base
      desc 'Install all required things for Karafka application in current directory'

      # Directories created by default
      INSTALL_DIRS = %w[
        app/consumers
        config
        log
        lib
      ].freeze

      # Where should we map proper files from templates
      INSTALL_FILES_MAP = {
        'karafka.rb.erb' => Karafka.boot_file.basename,
        'application_consumer.rb.erb' => 'app/consumers/application_consumer.rb',
        'example_consumer.rb.erb' => 'app/consumers/example_consumer.rb'
      }.freeze

      # @param args [Array] all the things that Thor CLI accepts
      def initialize(*args)
        super
        dependencies = Bundler::LockfileParser.new(
          Bundler.read_file(
            Bundler.default_lockfile
          )
        ).dependencies

        @rails = dependencies.key?('railties') || dependencies.key?('rails')
      end

      # Install all required things for Karafka application in current directory
      def call
        INSTALL_DIRS.each do |dir|
          FileUtils.mkdir_p Karafka.root.join(dir)
        end

        INSTALL_FILES_MAP.each do |source, target|
          target = Karafka.root.join(target)

          template = File.read(Karafka.core_root.join("templates/#{source}"))
          render = ::ERB.new(template, trim_mode: '-').result(binding)

          File.open(target, 'w') { |file| file.write(render) }
        end
      end

      # @return [Boolean] true if we have Rails loaded
      # This allows us to generate customized karafka.rb template with some tweaks specific for
      # Rails
      def rails?
        @rails
      end
    end
  end
end
