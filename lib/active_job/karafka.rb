# frozen_string_literal: true

require 'active_job'
require 'active_job/queue_adapters'
require 'active_job/queue_adapters/karafka_adapter'

require 'karafka/active_job/adapter'
require 'karafka/active_job/consumer'
require 'karafka/active_job/routing_extensions'
require 'karafka/active_job/job_extensions'

module ActiveJob
  # Namespace for usage simplification outside of Rails where Railtie will not kick in.
  # That way a require 'active_job/karafka' should be enough to use it
  module Karafka
  end
end

# We extend routing builder by adding a simple wrapper for easier jobs topics defining
::Karafka::Routing::Builder.include ::Karafka::ActiveJob::RoutingExtensions
::Karafka::Routing::Proxy.include ::Karafka::ActiveJob::RoutingExtensions
# This is our adapter in ActiveJob namespace, so we can expand it
::ActiveJob::QueueAdapters::KarafkaAdapter.include ::Karafka::ActiveJob::Adapter

# We extend ActiveJob stuff in the railtie
