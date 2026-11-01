class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :color, null: false, default: 'violet'
      t.string :icon, null: true
      t.decimal :position, null: false
      t.datetime :archived_at, null: true
      t.timestamps
    end
  end
end
