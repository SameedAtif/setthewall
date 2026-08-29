class ProposeJob < ApplicationJob
  queue_as :default

  def perform(cycle_id:)
    KbEvolution::Proposer.call(cycle_id: cycle_id)
  end
end
