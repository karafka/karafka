# frozen_string_literal: true

module ActiveJob
  # Namespace for usage simplification outside of Rails where Railtie will not kick in.
  # That way a require 'active_job/karafka' should be enough to use it
  module Karafka
  end
end

begin
  require 'active_job'
  require 'active_job/queue_adapters'
  require 'active_job/queue_adapters/karafka_adapter'

  # We extend routing builder by adding a simple wrapper for easier jobs topics defining
  # This needs to be extended here as it is going to be used in karafka routes, hence doing that in
  # the railtie initializer would be too late
  ::Karafka::Routing::Builder.include ::Karafka::ActiveJob::RoutingExtensions
  ::Karafka::Routing::Proxy.include ::Karafka::ActiveJob::RoutingExtensions

  # We extend ActiveJob stuff in the railtie
rescue LoadError
  # Nothing needed, ActiveJob not detected
end
