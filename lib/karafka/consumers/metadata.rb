# frozen_string_literal: true

module Karafka
  module Consumers
    # Brings the metadata into consumers that suport batch_fetching
    module Metadata
      attr_accessor :metadata
    end
  end
end
