# frozen_string_literal: true

# When we consume data and several times we loose and regain partition, there should be
# continuity in what messages we pick up even if rebalances happen multiple times
