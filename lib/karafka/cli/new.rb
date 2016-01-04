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
    FILES_MAP = {
      'app.rb.example' => 'app.rb',
      'config.ru.example' => 'config.ru',
      'rakefile.rb.example' => 'rakefile.rb',
      'sidekiq.yml.example' => 'config/sidekiq.yml.example'
    }

    desc 'new', 'Create a new Karafka application in current directory'
    method_option :new
    def new
      INSTALL_DIRS.each do |dir|
        FileUtils.mkdir_p File.join('./', dir)
      end

      FILES_MAP.each do |source, target|
        FileUtils.cp_r(
          Karafka.core_root.join("templates/#{source}"),
          File.join('./', target)
        )
      end
    end
  end
end
