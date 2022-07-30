# frozen_string_literal: true

class Object
  def self.logger
    raise
  end

  def logger
    raise
  end
end

guarded = []

setup_karafka do |config|
end
