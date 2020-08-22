# frozen_string_literal: true

module Karafka
  module Consumers
    # Brings the batch metadata into consumers that support batch_fetching
    module BatchMetadata
      attr_accessor :batch_metadata
    end
  end
end
