# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract with validation rules for Karafka configuration details.
    #
    # @note There are many more configuration options inside of the
    #   `Karafka::Setup::Config` model, but we don't validate them here as they are
    #   validated per each route (topic + consumer_group) because they can be overwritten,
    #   so we validate all of that once all the routes are defined and ready.
    class Config < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      params do
        required(:client_id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:concurrency) { int? & gt?(0) }
        required(:consumer_mapper).filled
        required(:pause_timeout) { int? & gt?(0) }
        required(:pause_max_timeout) { int? & gt?(0) }
        required(:pause_with_exponential_backoff).filled(:bool?)
        required(:shutdown_timeout) { int? & gt?(0) }
      end

      rule(:pause_timeout, :pause_max_timeout, :pause_with_exponential_backoff) do
        if values[:pause_with_exponential_backoff] &&
           values[:pause_timeout].to_i > values[:pause_max_timeout].to_i
          key(:pause_max_timeout).failure(:max_timeout_size_for_exponential)
        end
      end
    end
  end
end
