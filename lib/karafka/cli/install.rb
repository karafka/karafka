module Karafka
  # Karafka framework Cli
  class Cli
    # Directories created by default
    INSTALL_DIRS = %w(
      app/models
      app/controllers
      config
      log
    )

    # Where should we map proper files from templates
    INSTALL_FILES_MAP = {
      'app.rb.example' => Karafka.boot_file,
      'config.ru.example' => Karafka.root.join('config.ru'),
      'sidekiq.yml.example' => Karafka.root.join('config/sidekiq.yml.example')
    }

    desc 'install', 'Install all required things for Karafka application in current directory'
    method_option :new
    # Install all required things for Karafka application in current directory
    def install
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
