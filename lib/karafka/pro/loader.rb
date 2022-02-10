# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this repository
# and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.
module Karafka
  module Pro
    # Loader requires and loads all the pro components only when they are needed
    class Loader
      class << self
        # Loads all the pro components and configures them wherever it is expected
        # @param config [Dry::Configurable::Config] whole app config that we can alter with pro
        #   components
        def setup(config)
          require_relative 'active_job/dispatcher'
          require_relative 'active_job/job_options_contract'

          config.internal.active_job.dispatcher = ActiveJob::Dispatcher.new
          config.internal.active_job.job_options_contract = ActiveJob::JobOptionsContract.new
        end
      end
    end
  end
end
