# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Contract for validating the options that can be altered with `#karafka_options` per job class
    # @note We keep this in the `Karafka::ActiveJob` namespace instead of `Karafka::Contracts` as
    #   we want to keep ActiveJob related Karafka components outside of the core Karafka code and
    #   all in the same place
    class JobOptionsContract < Contracts::Base
      params do
        optional(:dispatch_method).value(included_in?: %i[produce_async produce_sync])
      end
    end
  end
end
