# frozen_string_literal: true

module Karafka
  # Module containing classes and methods that provide some additional functionalities
  module Helpers
    # @note Taken from http://stackoverflow.com/questions/6407141
    # Multidelegator is used to delegate calls to multiple targets
    class MultiDelegator
      # @param targets to which we want to delegate methods
      #
      def initialize(*targets)
        @targets = targets
      end

      class << self
        # @param methods names that should be delegated to
        # @example Delegate write and close to STDOUT and file
        #   Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file)
        def delegate(*methods)
          methods.each do |m|
            define_method(m) do |*args|
              @targets.map { |t| t.send(m, *args) }
            end
          end

          self
        end

        alias to new
      end
    end
  end
end
