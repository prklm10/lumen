module Api
  module V1
    class FlashcardsController < BaseController
      DUE_LIMIT = 100

      before_action :set_card, only: %i[update destroy review]

      # GET /flashcards?note_id= | ?topic_id=
      def index
        cards = Flashcard.order(:due_on, :id)
        cards = cards.where(note_id: params[:note_id]) if params[:note_id].present?
        cards = cards.where(topic_id: params[:topic_id]) if params[:topic_id].present?
        render json: { flashcards: FlashcardResource.new(cards.limit(500)).to_h }
      end

      # GET /flashcards/due — today's review queue, plus how many are coming up this week.
      def due
        cards = Flashcard.due.order(:due_on, :id).limit(DUE_LIMIT)
        upcoming = Flashcard.where(due_on: (Date.current + 1)..(Date.current + 7)).group(:due_on).count.sort.map { |d, n| { date: d, count: n } }
        render json: { flashcards: FlashcardResource.new(cards, params: { preview: true }).to_h, due_count: Flashcard.due.count, total: Flashcard.count, upcoming: }
      end

      def create
        card = Flashcard.new(params.require(:flashcard).permit(:note_id, :topic_id, :front, :back))
        card.save ? render(json: FlashcardResource.new(card).to_h, status: :created) : render_validation_errors(card)
      end

      # Cards written as "Q :: A" in a note are edited in the note, not here.
      def update
        return render_error(:conflict, "managed_by_note", "Edit this card in its note.") if @card.from_note_syntax

        @card.update(params.require(:flashcard).permit(:front, :back, :topic_id)) ? render(json: FlashcardResource.new(@card).to_h) : render_validation_errors(@card)
      end

      def destroy
        @card.destroy!
        head :no_content
      end

      # POST /flashcards/:id/review { grade: 0–5 }
      def review
        grade = Integer(params.require(:grade), exception: false)
        raise InvalidParameter, "grade must be 0–5" unless grade&.between?(0, 5)

        @card.review!(grade)
        render json: FlashcardResource.new(@card).to_h
      end

      private
        def set_card = @card = Flashcard.find(params[:id])
    end
  end
end
