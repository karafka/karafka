# frozen_string_literal: true

# Karafka in a PORO project should load components after the require even prior to the setup, so
# we can use those when needed

require 'karafka'

class Partitioner < Karafka::Pro::Processing::Partitioner
end
