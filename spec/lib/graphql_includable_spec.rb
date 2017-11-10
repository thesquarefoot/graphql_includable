require "graphql_includable"

RSpec.describe GraphQLIncludable, :type => :concern do
  include_examples "graphql"

  context "for basic associations" do
    it "includes a has_one association" do
      schema.execute("{ apple { tree { __typename } } }")
      expect(includes).to eq([:tree])
    end
    it "includes a has_many association" do
      schema.execute("{ tree { apples { __typename } } }")
      expect(includes).to eq([:apples])
    end
    it "includes associations defined using graphql `property`" do
      schema.execute("{ tree { yabloki { __typename } } }")
      expect(includes).to eq([:apples])
    end
    it "does not include fields which are GraphQL primitives" do
      schema.execute("{ apple { seeds } }")
      expect(includes).to eq([])
    end
    it "includes nested has_one -> has_many associations" do
      schema.execute("{ apple { tree { apples { __typename } } } }")
      expect(includes).to eq([{ tree: [:apples] }])
    end
    it "resolves through a non-ActiveRecord field" do
      schema.execute("{ orchard { trees { apples { __typename } } } }")
      expect(includes).to eq([:apples])
    end
  end

  context "for delegated associations" do
    it "does not include fields which are methods, not associations" do
      schema.execute("{ apple { juice } }")
      expect(includes).to eq([])
    end

    it "includes associations through delegated methods" do
      schema.execute("{ tree { worms { apple { __typename } } } }")
      expect(includes).to eq([{ apples: { worms: [:apple] } }])
    end

    it "includes attributes delegated multiple times" do
      schema.execute("{ tree { roots { worms { __typename } } } }")
      expect(includes).to eq([{ tree_roots: [{ tree: { apples: :worms } }] }])
    end
  end

  context "for associations defined using Field.includes" do
    it "includes nested associations through symbols" do
      schema.execute("{ tree { fruit { tree { __typename } } } }")
      expect(includes).to eq([{ apples: [:tree] }])
    end
    it "includes hashes explicitly" do
      schema.execute("{ tree { fruitWithTree { __typename } } }")
      expect(includes).to eq([{ apples: [:tree] }])
    end
  end
end
