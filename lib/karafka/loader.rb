module Karafka
  # Loader for requiring all the files in a proper order
  # Some files needs to be required before other, so it will
  # try to figure it out. It will load 'base*' files first and then
  # any other.
  class Loader
    # Order in which we want to load app files
    DIRS = %w(
      config/initializers
      lib
      app/helpers
      app/inputs
      app/decorators
      app/models/concerns
      app/models
      app/responders
      app/services
      app/presenters
      app/workers
      app/controllers
      app/aspects
      app
    ).freeze

    # Will load files in a proper order (based on DIRS)
    # @param [String] root path from which we want to start
    def load(root)
      DIRS.each do |dir|
        path = File.join(root, dir)
        load!(path)
      end
    end

    # Requires all the ruby files from one path in a proper order
    # @param path [String] path (dir) from which we want to load ruby files in a proper order
    # @note First we load all the base files that might be used in inheritance
    def load!(path)
      base_load!(path)
      files_load!(path)
    end

    # Requires all the ruby files from one relative path inside application directory
    # @param relative_path [String] relative path (dir) to a file inside application directory
    #   from which we want to load ruby files in a proper order
    def relative_load!(relative_path)
      path = File.join(::Karafka.root, relative_path)
      load!(path)
    end

    private

    # Loads all the base files
    # @param path [String] path (dir) from which we want to load ruby base files in a proper order
    def base_load!(path)
      bases = File.join(path, '**/base*.rb')
      Dir[bases].sort(&method(:base_sorter)).each(&method(:require))
    end

    # Loads all other files (not base)
    # @param path [String] path (dir) from which we want to load ruby files in a proper order
    # @note Technically it will load the base files again but they are already loaded so nothing
    #   will happen
    def files_load!(path)
      files = File.join(path, '**/*.rb')
      Dir[files].sort.each(&method(:require))
    end

    # @return [Integer] order for sorting
    # @note We need sort all base files based on their position in a file tree
    #   so all the files that are "higher" should be loaded first
    # @param str1 [String] first string for comparison
    # @param str2 [String] second string for comparison
    def base_sorter(str1, str2)
      str1.count('/') <=> str2.count('/')
    end
  end
end
