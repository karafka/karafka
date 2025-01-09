# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to define same pattern multiple times in the many consumer groups

setup_karafka

draw_routes(create_topics: false) do
  consumer_group :a do
    pattern(/non-existing-ever-na/) do
      consumer Class.new
    end
  end

  consumer_group :b do
    pattern(/non-existing-ever-na/) do
      consumer Class.new
    end
  end
end
