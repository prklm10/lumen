require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "subtree_ids walks every level with a recursive query" do
    deep = Folder.create!(name: "PG", parent: folders(:databases))
    assert_equal [ folders(:tech).id, folders(:databases).id, deep.id ].sort, Folder.subtree_ids(folders(:tech).id).sort
  end

  test "a folder can't move inside itself" do
    folders(:tech).parent = folders(:databases)
    assert_not folders(:tech).valid?
    assert folders(:tech).errors[:parent_id].any?
  end

  test "dissolving a folder moves its contents up a level" do
    folders(:databases).dissolve!
    assert_equal folders(:tech).id, notes(:indexes).reload.folder_id
    assert_not Folder.exists?(folders(:databases).id)
  end
end
