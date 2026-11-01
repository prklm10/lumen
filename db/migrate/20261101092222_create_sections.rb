class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 100
      t.decimal :position, null: false
      t.timestamps
    end
  end
end
