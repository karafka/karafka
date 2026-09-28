# frozen_string_literal: true

module Karafka
  module Connection
    # Legacy flat alias for the canonical {Karafka::Connection::ConsumerGroups::Listener}. Unlike
    # the other connection internals moved under `ConsumerGroups`, this constant is kept because
    # ecosystem gems (notably karafka-web) reference `Karafka::Connection::Listener` in `is_a?` /
    # `case` checks, so it is de-facto public API. New code should reference
    # `ConsumerGroups::Listener`. Scheduled for retirement in Karafka 3.0 once the ecosystem targets
    # the namespaced constant.
    Listener = ConsumerGroups::Listener
  end
end
