# frozen_string_literal: true

class Object
  def self.logger
    raise
  end

  def logger
    raise
  end
end

# If this would come back:
# https://github.com/karafka/karafka-core/issues/1

# This will crash
setup_karafka do |config|
end
