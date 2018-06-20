describe GraphQLIncludable::Concern do
  it 'attaches to a record instance' do
    class TestClass < ActiveRecord::Base
      include GraphQLIncludable::Concern
    end
    expect(TestClass).to respond_to(:includes_from_graphql)
  end

  it 'caches calls to the :delegate method' do
    class TestClass < ActiveRecord::Base
      include GraphQLIncludable::Concern
      delegate :test_method, to: :other_class
    end
    expect(TestClass.delegate_cache[:test_method]).to eq :other_class
  end
end
