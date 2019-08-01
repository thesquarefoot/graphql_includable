describe 'Relay Connection' do
  ListingType = GraphQL::ObjectType.define do
    name 'Listing'
    field :id, !types.ID
    field :address, !types.String
  end

  SurveyListingType = ListingType.define_edge do
    name 'SurveyListing'
    field :liked, !types.Boolean
  end

  SurveyType = GraphQL::ObjectType.define do
    name 'Survey'
    field :id, !types.ID
    field :listings, ListingType.define_connection_with_fetched_edge(edge_type: SurveyListingEdgeType, edge_to_node_property: :listing), edges_property: :survey_listings, nodes_property: :listings
  end

  SurveysField = GraphQL::Field.define do
    type !types[!SurveyType]
    resolve ->(obj, args, ctx) {
      Survey.includes_from_graphql(ctx).all
    }
  end

  let(:listing_1) { Listing.new(address: '1 Fake St') }
  let(:listing_2) { Listing.new(address: '2 Fake St') }
  let(:listing_3) { Listing.new(address: '3 Fake St') }

  let!(:survey) do
    survey = Survey.new
    survey.listings << listing_1
    survey.listings << listing_2
    survey
  end

  describe 'No connection requested' do
    it 'returns no includes' do

      byebug
    end
  end

  describe 'Asking for listings on a survey' do
    describe 'Only page info' do
    end

    describe 'Edges only' do

    end

    describe 'Nodes only' do

    end

    describe 'Nodes through edges' do

    end

    describe 'Nodes through edges and nodes' do

    end
  end
end
