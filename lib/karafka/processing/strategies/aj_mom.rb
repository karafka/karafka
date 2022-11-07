# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # ActiveJob enabled
      # Manual offset management enabled
      #
      # This is the default AJ strategy since AJ cannot be used without MOM
      module AjMom
        include Mom

        # Apply strategy when only when using AJ with MOM
        FEATURES = %i[
          active_job
          manual_offset_management
        ].freeze
      end
    end
  end
end
