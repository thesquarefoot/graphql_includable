def get_selection(query)
  GraphQL.parse(query).definitions[0].selections[0]
end

describe GraphQLIncludable::Resolver do
  describe 'default GraphQL <> ActiveRecord mapping' do
    it 'resolves from an ActiveModel to a GraphQL Type' do
    end
    it 'resolves from a GraphQL Type to an ActiveModel' do
    end
  end

  describe 'resolving includes for a field' do
    it 'uses the :includes definition' do
    end
    it 'uses the :property definition' do
    end
    it 'uses the field name' do
    end
  end

  describe 'resolving an associated field' do
    describe 'when the field is a Relay connection' do
      describe 'on a HasManyThroughAssociation' do
        it 'inserts the :through model' do
        end
        it 'continues traversing through the node fields' do
        end
      end
    end
    describe 'when the field refers to a delegated method on the model' do
    end
  end

  describe 'result formatting' do
    it 'places single terminal node as a symbol' do

    end
    it 'places multiple terminal nodes as an array of symbols' do
    end
    it 'places children as a hash' do
    end
    describe 'with both terminal nodes and nested children' do
      it 'returns an array with terminal nodes and a hash' do
      end
    end
  end

  ##################################################

  describe '.find_node_by_return_type' do
  end

  describe '.includes_for_node' do
  end

  describe '.includes_for_child' do
  end

  # helpers / utility
  describe '.model_name_to_class' do
    class TestClass < ActiveRecord::Base
    end

    it 'converts a model name to a class of the same name' do
      expect(GraphQLIncludable::Resolver.model_name_to_class(:test_class)).to eq(TestClass)
    end
    it 'converts a plural model name to a class of the singular name' do
      expect(GraphQLIncludable::Resolver.model_name_to_class(:test_classes)).to eq(TestClass)
    end
  end

  describe '.node_return_model' do
    class TestClass < ActiveRecord::Base
      include GraphQLIncludable::Concern
    end

    context 'when the node returns a basic type' do
      let(:TestType) do
        GraphQL::ObjectType.define do
          field :test_field, !types[!types.Boolean]
        end
      end
    end

    context 'when the node returns a nested type' do
      let(:TestType) do
        GraphQL::ObjectType.define do
          field :test_field, !types[!types.Boolean]
        end
      end
    end

    it 'only returns ActiveRecord types' do
    end
  end

  # describe '.node_predicted_association_name' do
  #   let(:irep_selection) do
  #     TestType = GraphQL::ObjectType.define do
  #       name 'Test'
  #       field :with_includes, types.Boolean, includes: :foo, property: :bar, resolve: ->(*_a) { true }
  #       field :with_property, types.Boolean, property: :bar, resolve: ->(*_a) { true }
  #       field :with_name, types.Boolean, resolve: ->(*_a) { true }
  #     end
  #     OT = GraphQL::ObjectType.define do
  #       name 'Base'
  #       field :test, TestType
  #     end
  #     schema = GraphQL::Schema.define { query OT }
  #     query = "query { test { with_includes } }"
  #     GraphQL::Query.new(schema, query).irep_selection
  #   end
  #   it 'uses the :includes definition' do
  #     expect(GraphQLIncludable::Resolver.node_predicted_association_name(irep_selection)).to eq(:foo)
  #   end
  #   it 'uses the :property definition' do
  #   end
  #   it 'uses the field name' do
  #   end
  # end

  describe '.includes_delegated_through' do
    before(:all) do
      class TestModel < ActiveRecord::Base
        include GraphQLIncludable::Concern
        delegate :delegated_method, to: :other_model
        def normal_method
        end
      end
    end

    context 'when the method is not delegated' do
      it 'returns an empty array' do
        expect(GraphQLIncludable::Resolver.includes_delegated_through(TestModel, :normal_method)).to eq([])
      end
    end
    context 'when the method is delegated' do
      it 'returns an array of delegated models' do
        expect(GraphQLIncludable::Resolver.includes_delegated_through(TestModel, :delegated_method)).to eq([:other_model])
      end
    end
  end

  describe '.array_to_nested_hash' do
    it 'reduces an array to a hash' do
      expect(GraphQLIncludable::Resolver.array_to_nested_hash([1,2,3])).to eq({ 1 => { 2 => 3 } })
    end
    it 'converts an empty array to an empty hash' do
      expect(GraphQLIncludable::Resolver.array_to_nested_hash([])).to eq({})
    end
  end
end
