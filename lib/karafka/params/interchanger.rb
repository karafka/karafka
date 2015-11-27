module Karafka
  module Params
    # Interchangers allow us to format/encode/pack data that is being send to perform_async
    # This is meant to target mostly issues with data encoding like this one:
    # https://github.com/mperham/sidekiq/issues/197
    # Each custom interchanger should implement following methods:
    #   - load - it is meant to encode params before they get stored inside Redis
    #   - parse - decoded params back to a hash format that we can use
    class Interchanger
      class << self
        # @param [Karafka::Params::Params] Karafka params object
        # @note Params might not be parsed because of lazy loading feature. If you implement your
        #   own interchanger logic, this method needs to return data that can be converted to
        #   json with default Sidekiqs logic
        # @return [Karafka::Params::Params] same as input. We assume that our incoming data is
        #   jsonable-safe and we can rely on a direct Sidekiq encoding logic
        def load(params)
          params
        end

        # @param [Hash] Sidekiqs params that are now a Hash (after they were JSON#parse)
        # @note Hash is what we need to build Karafka::Params::Params, so we do nothing
        #   with it. If you implement your own interchanger logic, this method needs to return
        #   a hash with appropriate data that will be used to build Karafka::Params::Params
        # @return [Hash] We return exactly what we received. We rely on sidekiqs default
        #   interchanging format
        def parse(params)
          params
        end
      end
    end
  end
end
