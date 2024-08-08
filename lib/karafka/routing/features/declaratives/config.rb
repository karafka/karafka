# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # Config for declarative topics feature
        Config = BaseConfig.define(
          :active,
          :partitions,
          :replication_factor,
          :details
        ) { alias_method :active?, :active }
      end
    end
  end
end
