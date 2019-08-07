class Parent < ActiveRecord::Base
  has_many :edges
  has_many :nodes, through: :edge
end
class Edge < ActiveRecord::Base
  belongs_to :parent
  belongs_to :node
end
class Node < ActiveRecord::Base
  has_many :edges
  has_many :parents, through: :edge
end

ParentType = GraphQL::ObjectType.define do
  name 'Parent'
  connection :connection, NodeType.define_connection(
    edge_class: GraphQLIncludable::Edge,
    edge_type: EdgeType,
    &block
  )
end
EdgeType = GraphQL::ObjectType.define do
  name 'Edge'
  field :test_edge_field, !types.Boolean
end
NodeType = GraphQL::ObjectType.define do
  name 'Node'
  field :test_node_field, !types.Boolean
end

describe GraphQLIncludable::Edge do
  context 'connecting a HasManyThroughAssociation' do
    describe 'a method called by the EdgeType' do
      it 'is resolved through the ActiveRecord join model' do
      end
    end
  end
end
