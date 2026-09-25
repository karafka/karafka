# frozen_string_literal: true

require "erb"

module Karafka
  class Cli
    # Install Karafka Cli action
    class Install < Base
      include Helpers::Colorize

      desc "Installs all required things for Karafka application in current directory"

      option(
        :share_groups,
        "Also installs the ApplicationShareConsumer base for share groups (KIP-932)",
        TrueClass,
        %w[--share_groups]
      )

      # Directories created by default
      INSTALL_DIRS = %w[
        app/consumers
        log
      ].freeze

      # Where should we map proper files from templates
      INSTALL_FILES_MAP = {
        "karafka.rb.erb" => Karafka.boot_file,
        "application_consumer.rb.erb" => "app/consumers/application_consumer.rb",
        "example_consumer.rb.erb" => "app/consumers/example_consumer.rb"
      }.freeze

      # Extra files installed only when the share groups (KIP-932) flag is passed. They are kept
      # out of the default install because the share group runtime is not available yet, but all
      # the wiring is here so the base can be generated on demand with
      # `karafka install --share_groups`.
      SHARE_GROUPS_FILES_MAP = {
        "application_share_consumer.rb.erb" => "app/consumers/application_share_consumer.rb"
      }.freeze

      # Initializes the install command
      def initialize
        super

        dependencies = Bundler::LockfileParser.new(
          Bundler.read_file(
            Bundler.default_lockfile
          )
        ).dependencies

        @rails = dependencies.key?("railties") || dependencies.key?("rails")
      end

      # Install all required things for Karafka application in current directory
      def call
        INSTALL_DIRS.each do |dir|
          FileUtils.mkdir_p Karafka.root.join(dir)
        end

        puts
        puts "Installing Karafka framework..."
        puts "Ruby on Rails detected..." if rails?
        puts

        files_map.each do |source, target|
          pathed_target = Karafka.root.join(target)
          FileUtils.mkdir_p File.dirname(pathed_target)

          template = File.read(Karafka.core_root.join("templates/#{source}"))
          render = ERB.new(template, trim_mode: "-").result(binding)

          File.write(pathed_target, render)

          puts "#{green("Created")} #{target}"
        end

        puts
        puts("Installation #{green("completed")}. Have fun!")
        puts
      end

      # @return [Boolean] true if we have Rails loaded
      # This allows us to generate customized karafka.rb template with some tweaks specific for
      # Rails
      def rails?
        @rails
      end

      private

      # @return [Hash] template source => target map to install, extended with the share group
      #   files only when the `--share_groups` flag was provided
      def files_map
        return INSTALL_FILES_MAP unless options[:share_groups]

        INSTALL_FILES_MAP.merge(SHARE_GROUPS_FILES_MAP)
      end
    end
  end
end
