module Workflow
  class InvalidTransition < StandardError; end

  class StatusMachine
    # Legal transitions.
    # Any → failed is always allowed (any step can raise). failed → running requires an
    # explicit resume (see ResumePieceJob).
    TRANSITIONS = {
      "pending"        => %w[running failed],
      "running"        => %w[pending awaiting_human complete failed],
      "awaiting_human" => %w[running failed],
      "complete"       => %w[],                              # terminal
      "failed"         => %w[running pending]                # explicit resume only
    }.freeze

    def self.transition!(piece, to:, current_step: nil, last_error: nil)
      return if piece.nil?

      from = piece.status
      allowed = TRANSITIONS.fetch(from, [])
      unless allowed.include?(to)
        raise InvalidTransition, "PieceRecord ##{piece.id}: #{from} → #{to} not allowed. " \
                                 "Legal from #{from}: #{allowed.join(', ')}"
      end

      piece.update!(
        status: to,
        current_step: current_step || piece.current_step,
        last_error: to == "failed" ? last_error : nil
      )
    end
  end
end
