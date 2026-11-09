module Api
  module V1
    class NotesController < BaseController
      before_action :set_note, only: %i[show update destroy]

      rescue_from ActiveRecord::StaleObjectError do
        render_error :conflict, "stale_note", "This note was changed in another tab or window. Reload it to see the latest version."
      end

      # Every kept note without its content — enough to draw the sidebar tree and resolve links.
      def index
        notes = Note.kept.select(:id, :title, :icon, :folder_id, :topic_id, :pinned, :position, :created_at, :updated_at).order(:position, :id)
        render json: { notes: NoteResource.new(notes).to_h }
      end

      def show
        render json: NoteDetailResource.new(@note).to_h
      end

      def create
        note = Note.new(note_params)
        note.save ? render(json: NoteDetailResource.new(note).to_h, status: :created) : render_validation_errors(note)
      end

      # Edits (title, content) send lock_version back: if someone else saved first, it's a 409.
      # Placement changes (folder, pin, order, icon) never conflict.
      def update
        attrs = note_params
        saved = if (attrs.keys - %w[lock_version] - Note::PLACEMENT_ATTRIBUTES).empty?
          @note.update_placement(attrs.except("lock_version"))
        else
          @note.update(attrs)
        end
        saved ? render(json: NoteDetailResource.new(@note).to_h) : render_validation_errors(@note)
      end

      def destroy
        @note.discard!
        head :no_content
      end

      private
        def set_note
          @note = Note.kept.includes(:tags).find(params[:id])
        end

        def note_params
          params.require(:note).except(:content).permit(:title, :icon, :folder_id, :topic_id, :pinned, :position, :lock_version).to_h.tap do |p|
            next unless params[:note].key?(:content)

            content = params[:note][:content]
            raise InvalidParameter, "content must be a JSON document" unless content.is_a?(ActionController::Parameters)
            p[:content] = content.to_unsafe_h
          end
        end
    end
  end
end
