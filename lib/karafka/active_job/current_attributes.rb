# frozen_string_literal: true

require 'active_support/current_attributes'
require_relative 'current_attributes/loading'
require_relative 'current_attributes/persistence'

# This code is based on Sidekiqs approach to persisting current attributes
# @see https://github.com/sidekiq/sidekiq/blob/main/lib/sidekiq/middleware/current_attributes.rb
module Karafka
  module ActiveJob
    # Module that allows to persist current attributes on Karafka jobs
    module CurrentAttributes
      # Allows for persistence of given current attributes via AJ + Karafka
      #
      # @param klasses [Array<String, Class>] classes or names of the current attributes classes
      def persist(*klasses)
        # Support for providing multiple classes
        klasses = Array(klasses).flatten

        [Dispatcher, Consumer]
          .reject { |expandable| expandable.respond_to?(:_cattr_klasses) }
          .each { |expandable| expandable.class_attribute :_cattr_klasses, default: {} }

        # Do not double inject in case of running persist multiple times
        Dispatcher.prepend(Persistence) unless Dispatcher.ancestors.include?(Persistence)
        Consumer.prepend(Loading) unless Consumer.ancestors.include?(Loading)

        klasses.map(&:to_s).each do |stringified_klass|
          # Prevent registering same klass multiple times
          next if Dispatcher._cattr_klasses.value?(stringified_klass)

          key = "cattr_#{Dispatcher._cattr_klasses.count}"

          Dispatcher._cattr_klasses[key] = stringified_klass
          Consumer._cattr_klasses[key] = stringified_klass
        end
      end

      module_function :persist
    end
  end
end
