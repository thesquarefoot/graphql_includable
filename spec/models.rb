class Survey < ActiveRecord::Base
  include GraphQLIncludable::Concern

  has_many :listings, through: :survey_listings
  has_many :survey_listings
end

class SurveyListing < ActiveRecord::Base
  belongs_to :listing

  def liked
    true
  end
end

class Listing < ActiveRecord::Base
  include GraphQLIncludable::Concern
end
