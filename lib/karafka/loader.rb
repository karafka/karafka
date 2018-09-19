# frozen_string_literal: true

module Karafka
  # Loader for requiring all the files in a proper order
  module Loader
    # Order in which we want to load app files
    DIRS = %w[
      lib
      app
    ].freeze

    private_constant :DIRS

    class << self
      # Will load files in a proper order (based on DIRS)
      # @param [String] root path from which we want to start
      def load(root)
        DIRS.each do |dir|
          path = File.join(root, dir)
          next unless File.exist?(path)

          load!(path)
        end
      end

      # Requires all the ruby files from one path in a proper order
      # @param path [String] path (dir) from which we want to load ruby files in a proper order
      def load!(path)
        require_all(path)
      end
    end
  end
end
