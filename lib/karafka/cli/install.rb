# frozen_string_literal: true

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
        config
        log
        tmp/pids
      ].freeze

      # Where should we map proper files from templates
      INSTALL_FILES_MAP = {
        'karafka.rb.example' => Karafka.boot_file.basename,
        'application_consumer.rb.example' => 'app/consumers/application_consumer.rb',
        'application_responder.rb.example' => 'app/responders/application_responder.rb'
      }.freeze

      # Install all required things for Karafka application in current directory
      def call
        INSTALL_DIRS.each do |dir|
          FileUtils.mkdir_p Karafka.root.join(dir)
        end

        INSTALL_FILES_MAP.each do |source, target|
          target = Karafka.root.join(target)
          next if File.exist?(target)

          source = Karafka.core_root.join("templates/#{source}")
          FileUtils.cp_r(source, target)
        end
      end
    end
  end
end
