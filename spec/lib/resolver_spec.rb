def get_selection(query)
  GraphQL.parse(query).definitions[0].selections[0]
end

describe GraphQLIncludable::Resolver do
  xdescribe '.find_node_by_return_type' do
    context 'when the node returns the requested type' do
      it 'returns the node' do
      end
    end
    context 'when the node has a child returning the requested type' do
      it 'returns the child node' do
      end
    end
    context 'when neither node nor children return the requested type' do
      it 'returns nothing' do
      end
    end
  end

  xdescribe '.includes_for_node' do
  end

  xdescribe '.includes_for_child' do
  end

  describe '.combine_child_includes' do
    it 'includes singular terminal nodes as symbols' do
      input = [:included]
      expected = [:included]
      expect(subject.class.combine_child_includes(input)).to match_array(expected)
    end
    it 'flatterns plural terminal nodes' do
      input = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expected = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      expect(subject.class.combine_child_includes(input)).to match_array(expected)
    end
    it 'combines multiple branching nodes into a single hash' do
      input = [{ foo: 'bar' }, { bar: 'baz' }]
      expected = [{ foo: 'bar', bar: 'baz' }]
      expect(subject.class.combine_child_includes(input)).to match_array(expected)
    end
  end

  describe '.model_name_to_class' do
    context 'when the class is an ActiveRecord model' do
      before do
        class GlobalTestClass < ActiveRecord::Base
        end
      end
      after do
        Object.send(:remove_const, :GlobalTestClass)
      end

      it 'converts a model name to a class of the same name' do
        expect(GraphQLIncludable::Resolver.model_name_to_class(:global_test_class)).to eq(GlobalTestClass)
      end
      it 'converts a plural model name to a class of the singular name' do
        expect(GraphQLIncludable::Resolver.model_name_to_class(:global_test_classes)).to eq(GlobalTestClass)
      end
    end
  end

  xdescribe '.node_return_model' do
    context 'when the node returns a normal gql object type' do
      context 'and the object type corresponds to an ActiveRecord model' do
        it 'returns the ActiveRecord class' do
        end
      end
      context 'and the object type is not an ActiveRecord model' do
        it 'returns nothing' do
        end
      end
    end

    context 'when the node returns a gql ListType' do
      it 'returns the wrapped object type\'s AR class' do
      end
    end

    context 'when the node returns a scalar' do
      it 'returns nothing' do
      end
    end
  end

  xdescribe '.node_includes_source_from_metadata' do
    let(:schema) do
      mock_schema_with_fields(
        test: GraphQL::ObjectType.define do
          name 'Test'
          field :with_includes, types.Boolean, includes: :foo, property: :bar, resolve: ->(*_a) { true }
          field :with_property, types.Boolean, property: :bar, resolve: ->(*_a) { true }
          field :with_name, types.Boolean, resolve: ->(*_a) { true }
        end
      )
    end
    let(:irep_selection) { irep_selection_from_query(schema, 'query { test { with_includes } }') }

    it 'uses the :includes definition' do
      expect(GraphQLIncludable::Resolver.node_includes_source_from_metadata(irep_selection)).to eq(:foo)
    end
    it 'uses the :property definition' do
    end
    it 'uses the field name' do
    end
  end

  describe '.includes_delegated_through' do
    context 'when the method is not delegated' do
      class self::TestModel < ActiveRecord::Base
        include GraphQLIncludable::Concern
      end

      it 'returns an empty array' do
        actual = GraphQLIncludable::Resolver.includes_delegated_through(self.class::TestModel, :delegated_method)
        expect(actual).to eq([])
      end
    end

    context 'when the method is delegated' do
      class self::TestModel < ActiveRecord::Base
        include GraphQLIncludable::Concern
        delegate :delegated_method, to: :other_model
      end

      it 'returns an array of delegated models' do
        actual = GraphQLIncludable::Resolver.includes_delegated_through(self.class::TestModel, :delegated_method)
        expect(actual).to eq([:other_model])
      end
    end
  end

  describe '.array_to_nested_hash' do
    it 'reduces an array to a hash' do
      input = [1, 2, 3]
      expected = { 1 => { 2 => 3 } }
      expect(GraphQLIncludable::Resolver.array_to_nested_hash(input)).to eq(expected)
    end
    it 'converts an empty array to an empty hash' do
      expect(GraphQLIncludable::Resolver.array_to_nested_hash([])).to eq({})
    end
  end
end
