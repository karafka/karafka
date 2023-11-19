# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # This feature allows to store per topic structure that can be later on used to bootstrap
      # topics structure for test/development, etc. This allows to share the same set of settings
      # for topics despite the environment. Pretty much similar to how the `structure.sql` or
      # `schema.rb` operate for SQL dbs.
      class Declaratives < Base
      end
    end
  end
end
