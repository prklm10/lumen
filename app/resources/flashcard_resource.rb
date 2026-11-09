class FlashcardResource
  include Alba::Resource

  attributes :id, :note_id, :topic_id, :front, :back, :from_note_syntax, :interval_days, :repetitions, :due_on, :last_reviewed_at
  attribute(:ease) { |c| c.ease.to_f }
  attribute(:preview, if: proc { params[:preview] }) { |c| c.preview }
end
