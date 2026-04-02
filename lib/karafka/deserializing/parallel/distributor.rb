# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Distributes payloads across Ractor workers for parallel deserialization
      #
      # Default strategy: split into at most 2×pool_size batches, but never smaller than
      # min_payloads messages per batch.
      #
      # Formula: num_batches = min(pool_size × 2, total / min_payloads)
      #
      # - 2×pool_size allows workers to pick up a second batch when they finish early,
      #   smoothing out variance without excessive dispatch overhead
      # - min_payloads floor ensures Ractor coordination cost (~30-50μs per batch) stays
      #   negligible relative to actual deserialization work
      # - Below min_payloads the Pool skips dispatch entirely (inline deserialization)
      class Distributor
        # @param payloads [Array<String>] raw payloads to distribute
        # @param pool_size [Integer] number of available workers
        # @param min_payloads [Integer] minimum batch size — batches will never be smaller
        # @return [Array<Array<String>>] batches for dispatch to workers
        def call(payloads, pool_size, min_payloads: 50)
          max_batches = [payloads.size / min_payloads, 1].max
          num_batches = [pool_size * 2, max_batches].min
          slice_size = (payloads.size + num_batches - 1) / num_batches
          payloads.each_slice(slice_size).to_a
        end
      end
    end
  end
end
