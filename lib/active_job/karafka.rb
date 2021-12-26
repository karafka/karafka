# frozen_string_literal: true

require 'active_job'
require 'active_job/queue_adapters'
require 'active_job/consumer'
require 'active_job/routing_extensions'
require 'active_job/queue_adapters/karafka_adapter'

module ActiveJob
  # Namespace for usage simplification outside of Rails where Railtie will not kick in.
  # That way a require 'active_job/karafka' should be enough to use it
  module Karafka
  end
end

# We extend routing builder by adding a simple wrapper for easier jobs topics defining
::Karafka::Routing::Builder.include ActiveJob::RoutingExtensions
::Karafka::Routing::Proxy.include ActiveJob::RoutingExtensions
