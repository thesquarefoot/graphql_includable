ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  create_table :clients, force: true do |t|
    t.string :name
    t.string :email
    t.integer :user_id
    t.timestamps
  end

  create_table :client_tasks, force: true do |t|
    t.boolean :completed
    t.integer :client_id
    t.integer :task_id
    t.timestamps
  end

  create_table :tasks, force: true do |t|
    t.string :name
    t.integer :location_id
    t.timestamps
  end

  create_table :locations, force: true do |t|
    t.string :name
    t.timestamps
  end
end
