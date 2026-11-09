require "rubygems/package" # Gem::Package::TarWriter, for the notes .tar.gz

module Api
  module V1
    # Data portability (PRD §11 "no lock-in"). Journal entries are exported exactly as stored:
    # ciphertext. Decrypted journal export happens in the browser (JRN-12).
    class ExportsController < BaseController
      # GET /export — everything as one JSON file.
      def show
        data = {
          exported_at: Time.current, format: "lumen-export/v1",
          projects: Project.all.as_json, sections: Section.all.as_json,
          tasks: Task.kept.includes(:tags).map { |t| t.as_json(except: :search_vector).merge(tags: t.tags.map(&:name)) },
          task_events: TaskEvent.all.as_json,
          folders: Folder.all.as_json,
          notes: Note.kept.includes(:tags).map { |n| n.as_json(except: %i[search_vector content_text]).merge(tags: n.tags.map(&:name), markdown: NoteMarkdown.new(n.content).to_s) },
          trackers: Tracker.all.as_json, tracker_entries: TrackerEntry.all.as_json,
          topics: Topic.all.as_json, resources: Resource.all.as_json, study_sessions: StudySession.all.as_json,
          flashcards: Flashcard.all.as_json, flashcard_reviews: FlashcardReview.all.as_json,
          journal: {
            note: "Encrypted in your browser. Decrypt with your passphrase in Lumen, or with the recovery key.",
            vault: Current.user.journal_vault&.then { |v| v.attributes.except("id", "user_id").transform_values { |x| x.is_a?(String) && x.encoding == Encoding::BINARY ? Base64.strict_encode64(x) : x } },
            entries: JournalEntry.order(:entry_date).map { |e| { id: e.id, entry_date: e.entry_date, version: e.version, iv: Base64.strict_encode64(e.iv), ciphertext: Base64.strict_encode64(e.ciphertext) } }
          }
        }
        send_data JSON.pretty_generate(data), filename: "lumen-export-#{Date.current}.json", type: "application/json"
      end

      # GET /export/notes — notes as Markdown files in their folders, one .tar.gz (stdlib only).
      def notes
        folders = Folder.all.index_by(&:id)
        used = Set.new
        io = StringIO.new
        Zlib::GzipWriter.wrap(io) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            Note.kept.includes(:tags).find_each do |note|
              path = unique_path(File.join("lumen-notes", *folder_path(folders, note.folder_id), "#{safe(note.title)}.md"), used)
              body = front_matter(note) + NoteMarkdown.new(note.content).to_s
              tar.add_file_simple(path, 0o644, body.bytesize) { |f| f.write(body) }
            end
          end
        end
        send_data io.string, filename: "lumen-notes-#{Date.current}.tar.gz", type: "application/gzip"
      end

      private
        def folder_path(folders, id, depth = 0)
          folder = folders[id]
          return [] unless folder && depth < 50
          folder_path(folders, folder.parent_id, depth + 1) + [ safe(folder.name) ]
        end

        def safe(name) = name.to_s.gsub(%r{[/\\:*?"<>|\x00-\x1f]}, "-").strip.first(120).presence || "Untitled"

        def unique_path(path, used)
          base, n = path.delete_suffix(".md"), 1
          path = "#{base} (#{n += 1}).md" while used.include?(path)
          used << path
          path
        end

        def front_matter(note)
          lines = [ "---", "title: #{note.title.to_json}", "created: #{note.created_at.iso8601}", "updated: #{note.updated_at.iso8601}" ]
          lines << "tags: [#{note.tags.map { |t| t.name.to_json }.join(", ")}]" if note.tags.any?
          (lines + [ "---", "" ]).join("\n")
        end
    end
  end
end
