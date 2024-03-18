# frozen_string_literal: true

module Karafka
  module Helpers
    # Simple wrapper for adding colors to strings
    module Colorize
      # @param string [String] string we want to have in green
      # @return [String] green string
      def green(string)
        "\033[0;32m#{string}\033[0m"
      end

      # @param string [String] string we want to have in red
      # @return [String] red string
      def red(string)
        "\033[0;31m#{string}\033[0m"
      end

      # @param string [String] string we want to have in yellow
      # @return [String] yellow string
      def yellow(string)
        "\033[1;33m#{string}\033[0m"
      end

      # @param string [String] string we want to have in grey
      # @return [String] grey string
      def grey(string)
        "\e[38;5;244m#{string}\e[0m"
      end
    end
  end
end
