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
        app/responders
        app/workers
        config
        lib
        log
        tmp/pids
      ].freeze

      # Where should we map proper files from templates
      INSTALL_FILES_MAP = {
        'karafka.rb.erb' => Karafka.boot_file.basename,
        'application_consumer.rb.erb' => 'app/consumers/application_consumer.rb',
        'application_responder.rb.erb' => 'app/responders/application_responder.rb'
      }.freeze

      # @param args [Array] all the things that Thor CLI accepts
      def initialize(*args)
        super
        @rails = Bundler::LockfileParser.new(
          Bundler.read_file(
            Bundler.default_lockfile
          )
        ).dependencies.key?('railties')
      end

      # Install all required things for Karafka application in current directory
      def call
        INSTALL_DIRS.each do |dir|
          FileUtils.mkdir_p Karafka.root.join(dir)
        end

        INSTALL_FILES_MAP.each do |source, target|
          target = Karafka.root.join(target)

          template = File.read(Karafka.core_root.join("templates/#{source}"))
          # @todo Replace with the keyword argument version once we don't have to support
          # Ruby < 2.6
          render = ::ERB.new(template, nil, '-').result(binding)

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
