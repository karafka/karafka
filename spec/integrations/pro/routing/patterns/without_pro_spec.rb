# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running non-pro, patterns should not be available

setup_karafka(pro: false)

not_found = false

begin
  draw_routes(create_topics: false) do
    pattern(/.*/) do
      consumer Class.new
    end
  end
rescue NoMethodError
  not_found = true
end

assert not_found
