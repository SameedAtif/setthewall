class ReviewsController < ApplicationController
  def index
    @open_gates = HumanGate.open
                           .includes(:piece_record)
                           .order(opened_at: :desc)
                           .limit(50)
    @failed_pieces = PieceRecord.where(status: "failed")
                                .order(updated_at: :desc)
                                .limit(20)
  end
end
