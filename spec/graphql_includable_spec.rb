require 'graphql_includable'

"""
Prose testing plan (to review)

basic AR:
  has_one   { a { b { id } } } -> a.includes_from_graphql -> [:b]
  has_many  { b { as { id } } } -> b.includes_from_graphql -> [:as]
  has_one w/ property: property: :c -> a.includes_from_graphql -> [:c]
  has_many_through
  has_many_through polymorphic
nested AR -- AR has_N -> has_N nested  { a { b { as { id } } } } -> a.includes_from_graphql -> [{ b: [:as] }]
delegated AR
nested delegated AR
overrides:
  includes: :some_assn_by_name (vals should pass through using an association by name)
  includes: :arbitrary_val (vals neednt pass through if not an assn, but include the arbitrary val)
  includes: { some: :hash } (hash vals included arbitrarily)
multiple base field - finds first field returning type    { a { b { id } } b { a { id } } c { a { id } } } -> a.includes_from_graphql -> [:b]
edges calls methods on resolve on correct model/record in has_many_through relations
edges calls methods on resolve on correct model/record in has_many_through relations for polymorphic types





class BaseExampleClass
  has_one :singular
  has_many :plurals
  has_many :plurals_by_any_other_name
  has_many :edges
  has_many :target_nodes, through: :edges
  has_many :things, as: :thingable, polymorphic: true
  delegate :delegated_method, to: :singular
end
"""

RSpec.describe GraphQLIncludable, type: :concern do
  include_examples 'graphql'

  context 'for basic associations' do
    it 'includes a has_one association' do
      schema.execute('{ apple { tree { __typename } } }')
      expect(includes).to eq([:tree])
    end
    it 'includes a has_many association' do
      schema.execute('{ tree { apples { __typename } } }')
      expect(includes).to eq([:apples])
    end
    it 'includes associations defined using graphql `property`' do
      schema.execute('{ tree { yabloki { __typename } } }')
      expect(includes).to eq([:apples])
    end
    it 'does not include fields which are GraphQL primitives' do
      schema.execute('{ apple { seeds } }')
      expect(includes).to eq([])
    end
    it 'includes nested has_one -> has_many associations' do
      schema.execute('{ apple { tree { apples { __typename } } } }')
      expect(includes).to eq([{ tree: [:apples] }])
    end
    it 'resolves through a non-ActiveRecord field' do
      schema.execute('{ orchard { trees { apples { __typename } } } }')
      expect(includes).to eq([:apples])
    end
  end

  context 'for delegated associations' do
    it 'does not include fields which are methods, not associations' do
      schema.execute('{ apple { juice } }')
      expect(includes).to eq([])
    end

    it 'includes associations through delegated methods' do
      schema.execute('{ tree { worms { apple { __typename } } } }')
      expect(includes).to eq([{ apples: { worms: [:apple] } }])
    end
  end

  context 'for associations defined using Field.includes' do
    it 'includes nested associations through symbols' do
      schema.execute('{ tree { fruit { tree { __typename } } } }')
      expect(includes).to eq([{ apples: [:tree] }])
    end
    it 'includes hashes explicitly' do
      schema.execute('{ tree { fruitWithTree { __typename } } }')
      expect(includes).to eq([{ apples: [:tree] }])
    end
  end
end
