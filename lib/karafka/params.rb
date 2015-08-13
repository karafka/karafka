module Karafka
  # Class-wrapper for hash with indifferent access
  class Params
    attr_reader :params

    def initialize(params)
      @params = params
    end

    # Parse params. Return params as HashWithIndifferentAccess if
    # params can be deserialized from a JSON string or String otherwise
    def parse
      HashWithIndifferentAccess.new(
        JSON.parse(params)
      )
    rescue JSON::ParserError
      params.to_s
    end
  end
end
