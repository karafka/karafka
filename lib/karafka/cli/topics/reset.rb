# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Deletes routing based topics and re-creates them
      class Reset < Base
        # @return [true] since it is a reset, always changes so `true` always
        def call
          Delete.new.call && wait
          Create.new.call

          true
        end
      end
    end
  end
end
