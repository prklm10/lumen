class Note < ApplicationRecord
  include Discardable
  include Positionable
  include Taggable

  MAX_TEXT_LENGTH = 1_000_000

  belongs_to :folder, optional: true
  belongs_to :topic, optional: true
  has_many :flashcards, dependent: :nullify
  has_many :outgoing_links, class_name: "NoteLink", foreign_key: :source_note_id, inverse_of: :source_note
  has_many :incoming_links, class_name: "NoteLink", foreign_key: :target_note_id, inverse_of: :target_note

  scope :recent, -> { order(updated_at: :desc) }

  normalizes :title, with: ->(title) { title.to_s.squish.presence || "Untitled" }

  validates :title, length: { maximum: 200 }
  validates :content_text, length: { maximum: MAX_TEXT_LENGTH, message: "is too long" }
  validate :content_is_a_document

  before_validation :extract_text, if: :content_changed?
  after_save :sync_links_and_tags, if: -> { saved_change_to_content? }
  after_save :claim_dangling_links, if: -> { saved_change_to_title? || saved_change_to_discarded_at? }

  PLACEMENT_ATTRIBUTES = %w[folder_id pinned position icon topic_id].freeze

  # Moving, pinning or reordering isn't an edit: it skips optimistic locking (so a note open in
  # the editor doesn't hit a false conflict) and doesn't bump updated_at ("recently edited").
  def update_placement(attrs)
    assign_attributes(attrs)
    errors.add(:folder_id, "doesn't exist") if folder_id_changed? && folder_id && !Folder.exists?(folder_id)
    errors.add(:icon, "is too long") if icon.to_s.length > 16
    errors.add(:topic_id, "doesn't exist") if topic_id_changed? && topic_id && !Topic.exists?(topic_id)
    return false if errors.any?

    self.position = nil if folder_id_changed? && !position_changed?
    append_to_end if position.nil?
    update_columns(attrs.keys.index_with { |key| self[key] }.merge("position" => position))
  end

  def restore! = update!(discarded_at: nil)

  # Kept notes that link here.
  def backlinks
    Note.kept.where(id: incoming_links.select(:source_note_id)).where.not(id:).order(:title)
  end

  private
    def position_siblings = Note.kept.where(folder_id:)
    def parsed_content = @parsed_content ||= NoteContent.new(content)

    def extract_text
      @parsed_content = nil
      self.content_text = parsed_content.text
    end

    # Rewrites this note's outgoing links and tags from its content (same transaction as the save).
    def sync_links_and_tags
      links = parsed_content.links
      titles = links.map { |l| l.title.downcase }
      outgoing_links.where.not("lower(target_title::text) IN (?)", titles.presence || [ "" ]).delete_all

      if links.any?
        by_id = Note.kept.where(id: links.filter_map(&:note_id)).pluck(:id).to_set
        by_title = Note.kept.where("lower(title) IN (?)", titles).pluck(Arel.sql("lower(title)"), :id).to_h
        rows = links.map do |link|
          target = link.note_id if by_id.include?(link.note_id)
          { source_note_id: id, target_title: link.title, target_note_id: target || by_title[link.title.downcase], created_at: Time.current }
        end
        NoteLink.upsert_all(rows, unique_by: %i[source_note_id target_title], update_only: %i[target_note_id])
      end

      self.tag_names = parsed_content.tag_names
      Flashcard.sync_from_note(self)
    end

    # A link written before its target existed ([[Some idea]]) attaches when the note appears.
    def claim_dangling_links
      return if discarded?
      NoteLink.where(target_note_id: nil).where("lower(target_title::text) = ?", title.downcase).update_all(target_note_id: id)
    end

    def content_is_a_document
      errors.add(:content, "must be a document") unless content.is_a?(Hash) && content["type"] == "doc"
    end
end
