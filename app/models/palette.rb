# Named colors shared by projects and tags. The UI maps each name to a Tailwind color;
# the database enforces the same list with CHECK constraints (see FinishTasksSchema).
module Palette
  COLORS = %w[gray red orange amber yellow lime green teal cyan blue indigo violet purple pink].freeze
end
