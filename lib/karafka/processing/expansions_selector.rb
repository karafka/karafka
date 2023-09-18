# frozen_string_literal: true

module Karafka
  module Processing
    # Selector of appropriate processing strategy matching topic combinations
    class ExpansionsSelector
      attr_reader :strategies

      # Features we support in the OSS offering.
      SUPPORTED_FEATURES = %i[
        inline_statistics
      ].freeze

      # @param topic [Karafka::Routing::Topic] topic with settings based on which we find strategy
      # @return [Module] module with proper strategy
      def find(topic)
        expansions = []

        SUPPORTED_FEATURES.each do |feature|
          #next unless topic.public_send("#{feature}?")

          mod = topic.public_send(feature).class.name.split('::')[0..-2].join('::') + '::Consumer'

          next unless ::Object.const_defined?(mod, false)

          expansions << ::Object.const_get(mod, false)
        end

        expansions
      end
    end
  end
end
