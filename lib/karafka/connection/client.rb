# frozen_string_literal: true

module Karafka
  module Connection
    # Legacy flat alias for the canonical {Karafka::Connection::ConsumerGroups::Client}. Unlike the
    # other connection internals moved under `ConsumerGroups`, this constant is kept because
    # ecosystem gems (notably karafka-web) reference `Karafka::Connection::Client` in `is_a?` /
    # `case` checks, so it is de-facto public API. New code should reference
    # `ConsumerGroups::Client`. Scheduled for retirement in Karafka 3.0 once the ecosystem targets
    # the namespaced constant.
    Client = ConsumerGroups::Client
  end
end
