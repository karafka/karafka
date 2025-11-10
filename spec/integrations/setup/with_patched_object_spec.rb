# frozen_string_literal: true

# Karafka setup should not crash even when Object class has been patched with logger methods
# that raise errors

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
setup_karafka do |_config|
  nil
end
