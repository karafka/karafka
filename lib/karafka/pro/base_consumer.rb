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
    # Karafka PRO consumer.
    #
    # If you use PRO, all your consumers should inherit (indirectly) from it.
    #
    # @note In case of using lrj, manual pausing may not be the best idea as resume needs to happen
    #   after each batch is processed.
    class BaseConsumer < Karafka::BaseConsumer
    end
  end
end
