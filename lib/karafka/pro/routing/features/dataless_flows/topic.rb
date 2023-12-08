# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Routing
      module Features
        class DatalessFlows < Base
          # Topic action dataless flows extensions
          module Topic
            def dataless_flows(active: false, on: %i[])
              @dataless_flows ||= begin
                active = true unless on.empty?
                on << :polling if active && on.empty?

                Config.new(active: active, on: on.uniq)
              end
            end

            def dataless_flows?
              dataless_flow.active?
            end

            # @return [Hash] topic with all its native configuration options plus dataless flows
            #   settings
            def to_h
              super.merge(
                dataless_flows: dataless_flows.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
