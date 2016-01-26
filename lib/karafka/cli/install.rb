module Karafka
  # Karafka framework Cli
  class Cli
    # Install Karafka Cli action
    class Install < Base
      self.desc = 'Install all required things for Karafka application in current directory'

      # Directories created by default
      INSTALL_DIRS = %w(
        app/models
        app/controllers
        config
        log
      ).freeze

      # Where should we map proper files from templates
      INSTALL_FILES_MAP = {
        'app.rb.example' => Karafka.boot_file,
        'config.ru.example' => Karafka.root.join('config.ru'),
        'sidekiq.yml.example' => Karafka.root.join('config/sidekiq.yml.example')
      }.freeze

      # Install all required things for Karafka application in current directory
      def call
        INSTALL_DIRS.each do |dir|
          FileUtils.mkdir_p Karafka.root.join(dir)
        end

        INSTALL_FILES_MAP.each do |source, target|
          next if File.exist?(target)

          source = Karafka.core_root.join("templates/#{source}")
          FileUtils.cp_r(source, target)
        end
      end
    end
  end
end
