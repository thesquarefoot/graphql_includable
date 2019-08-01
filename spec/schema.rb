ActiveRecord::Schema.define do
  self.verbose = false

  create_table :surveys, :force => true do |t|
  end

  create_table :survey_listings, :force => true do |t|
    t.references :survey
    t.references :listing

    t.boolean :liked
  end

  create_table :listings, :force => true do |t|
    t.string :address
  end
end
