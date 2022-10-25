# frozen_string_literal: true

begin
  require 'active_job'
  require_relative 'queue_adapters/karafka_adapter'

  module ActiveJob
    # Namespace for usage simplification outside of Rails where Railtie will not kick in.
    # That way a require 'active_job/karafka' should be enough to use it
    module Karafka
    end
  end
rescue LoadError
  # We extend ActiveJob stuff in the railtie
end
