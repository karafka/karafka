# frozen_string_literal: true

module Karafka
  module Pro
    module ActiveJob
      # This Karafka component is a Pro component.
      # All of the commercial components are present in the lib/karafka/pro directory of this
      # repository and their usage requires commercial license agreement.
      #
      # Karafka has also commercial-friendly license, commercial support and commercial components.
      #
      # By sending a pull request to the pro components, you are agreeing to transfer the copyright
      # of your code to Maciej Mensfeld.

      # Pro ActiveJob consumer that is suppose to handle long-running jobs as well as short
      # running jobs
      class Consumer < Karafka::ActiveJob::Consumer
      end
    end
  end
end
