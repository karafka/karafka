# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# It should be possible to use same named pattern twice in different consumer groups

setup_karafka

draw_routes(create_topics: false) do
  subscription_group :a do
    pattern('super-name', /non-existing-ever-na/) do
      consumer Class.new
    end
  end

  consumer_group :b do
    subscription_group :a do
      pattern('super-name', /non-existing-ever-na/) do
        consumer Class.new
      end
    end
  end
end
