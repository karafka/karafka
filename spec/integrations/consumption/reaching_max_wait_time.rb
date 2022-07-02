# frozen_string_literal: true

# When we have a max_wait_time and we did not reach the requested number of messages, we should
# wait for at most the max time we requested. We also should not wait shorter period of time, as
# the messages number is not satisfied.

# pending
