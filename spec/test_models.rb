class TestRecord < ActiveRecord::Base
  self.abstract_class = true
  include GraphQLIncludable::Concern
end

class Apple < TestRecord
  belongs_to :tree
  has_many :worms

  def juice
    42
  end
end

class Tree < TestRecord
  has_many :apples
  has_many :tree_roots
  has_many :roots, through: :tree_roots
  delegate :worms, to: :apples

  def fruit
    apples
  end
end

class TreeRoot < TestRecord
  belongs_to :tree
  belongs_to :root
  delegate :worms, to: :tree
end

class Root < TestRecord
  has_many :tree_roots
  has_many :trees, through: :tree_roots
end

class Worm < TestRecord
  belongs_to :apple
end
