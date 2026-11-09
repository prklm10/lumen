# The Weekly Review (PRD §4.8 Reviews): a summary of one ISO week across modules, regenerated
# from live data every time. Task titles are included (tasks aren't sensitive); the journal
# contributes only which days had an entry.
class WeeklyReviewQuery
  def initialize(week_start)
    @from = week_start.beginning_of_week
    @to = @from + 6
    @window = @from.in_time_zone.beginning_of_day..@to.in_time_zone.end_of_day
  end

  def call
    {
      week: { from: @from, to: @to },
      tasks: tasks,
      habits: habits,
      notes: Note.kept.where(updated_at: @window).order(updated_at: :desc).limit(20)
        .map { |n| { id: n.id, title: n.title, created: @window.cover?(n.created_at) } },
      study: {
        minutes: StudySession.where(studied_on: @from..@to).sum(:duration_minutes),
        by_topic: StudySession.where(studied_on: @from..@to).left_joins(:topic).group("topics.name").sum(:duration_minutes)
          .map { |name, minutes| { topic: name || "No topic", minutes: } }.sort_by { |t| -t[:minutes] }
      },
      flashcards_reviewed: FlashcardReview.where(reviewed_at: @window).count,
      journal_days: JournalEntry.where(entry_date: @from..@to).distinct.pluck(:entry_date).sort
    }
  end

  private
    def tasks
      done = Task.kept.done.where(completed_at: @window).includes(:project).order(:completed_at)
      {
        completed: done.map { |t| { id: t.id, title: t.title, project: t.project&.name, completed_on: t.completed_at.to_date } },
        created: Task.kept.where(created_at: @window).count,
        still_overdue: Task.kept.open.where(due_date: ...[ @to + 1, Date.current ].min).count
      }
    end

    def habits
      trackers = Tracker.active.ordered.to_a
      entries = TrackerEntry.where(tracker: trackers, logged_on: @from..@to).group_by(&:tracker_id)
      trackers.map do |t|
        days = entries.fetch(t.id, [])
        { id: t.id, name: t.name, icon: t.icon, met: days.count { |e| t.met?(e.value) }, logged: days.size }
      end
    end
end
