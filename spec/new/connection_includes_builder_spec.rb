require 'spec_helper'

describe GraphQLIncludable::New::ConnectionIncludesBuilder do
  context 'A connection with only nodes' do
    context 'with no siblings or deep nesting' do
      it 'generates the correct includes pattern' do
        builder = subject
        builder.nodes(:nodes_a)

        expect(builder.includes?).to eq(true)
        expect(builder.nodes_builder.includes?).to eq(true)
        expect(builder.nodes_builder.included_path).to eq([:nodes_a])
        expect(builder.nodes_builder.active_record_includes).to eq([:nodes_a])

        expect(builder.edges_builder.builder.includes?).to eq(false)
        expect(builder.edges_builder.builder.included_path).to eq([])
        expect(builder.edges_builder.builder.active_record_includes).to eq({})

        expect(builder.edges_builder.node_builder.includes?).to eq(false)
        expect(builder.edges_builder.node_builder.included_path).to eq([])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq({})
      end
    end

    context 'with deep nesting' do
      it 'generates the correct includes pattern' do
        builder = subject
        builder.nodes(:through_something, :to, :nodes_a)
        builder.edges do
          path(:through_something)
          node(:node_on_edge_a)
        end

        expect(builder.includes?).to eq(true)
        expect(builder.nodes_builder.includes?).to eq(true)
        expect(builder.nodes_builder.included_path).to eq([:through_something, :to, :nodes_a])
        expect(builder.nodes_builder.active_record_includes).to eq({ through_something: { to: [:nodes_a] } })

        expect(builder.edges_builder.builder.includes?).to eq(true)
        expect(builder.edges_builder.builder.included_path).to eq([:through_something])
        expect(builder.edges_builder.builder.active_record_includes).to eq([:through_something])

        expect(builder.edges_builder.node_builder.includes?).to eq(true)
        expect(builder.edges_builder.node_builder.included_path).to eq([:node_on_edge_a])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq([:node_on_edge_a])
      end
    end
  end

  context 'A connection with only edges and node' do
    context 'when only edges is given' do
      it 'does not generate includes' do
        builder = subject
        builder.edges { path(:edges_a) }

        expect(builder.includes?).to eq(false)
        expect(builder.nodes_builder.includes?).to eq(false)

        expect(builder.edges_builder.builder.includes?).to eq(true)
        expect(builder.edges_builder.builder.included_path).to eq([:edges_a])
        expect(builder.edges_builder.builder.active_record_includes).to eq([:edges_a])

        expect(builder.edges_builder.node_builder.includes?).to eq(false)
        expect(builder.edges_builder.node_builder.included_path).to eq([])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq({})
      end
    end

    context 'when only edge_node is given' do
      it 'does not generate includes' do
        builder = subject
        builder.edges { node(:node_on_edge_a) }

        expect(builder.includes?).to eq(false)
        expect(builder.nodes_builder.includes?).to eq(false)

        expect(builder.edges_builder.builder.includes?).to eq(false)
        expect(builder.edges_builder.builder.included_path).to eq([])
        expect(builder.edges_builder.builder.active_record_includes).to eq({})

        expect(builder.edges_builder.node_builder.includes?).to eq(true)
        expect(builder.edges_builder.node_builder.included_path).to eq([:node_on_edge_a])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq([:node_on_edge_a])
      end
    end

    context 'when edges and edge_node are given' do
      it 'generates the correct includes pattern' do
        builder = subject
        builder.edges do
          path(:edges_a)
          node(:node_on_edge_a)
        end

        expect(builder.includes?).to eq(true)
        expect(builder.nodes_builder.includes?).to eq(false)
        expect(builder.nodes_builder.included_path).to eq([])
        expect(builder.nodes_builder.active_record_includes).to eq({})

        expect(builder.edges_builder.builder.includes?).to eq(true)
        expect(builder.edges_builder.builder.included_path).to eq([:edges_a])
        expect(builder.edges_builder.builder.active_record_includes).to eq([:edges_a])

        expect(builder.edges_builder.node_builder.includes?).to eq(true)
        expect(builder.edges_builder.node_builder.included_path).to eq([:node_on_edge_a])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq([:node_on_edge_a])
      end
    end
  end

  context 'A connection with nodes and edges' do
    context 'with no siblings or deep nesting' do
      it 'generates the correct includes pattern' do
        builder = subject
        builder.nodes(:nodes_a)
        builder.edges do
          path(:edges_a)
          node(:node_on_edge_a)
        end

        expect(builder.includes?).to eq(true)
        expect(builder.nodes_builder.includes?).to eq(true)
        expect(builder.nodes_builder.included_path).to eq([:nodes_a])
        expect(builder.nodes_builder.active_record_includes).to eq([:nodes_a])

        expect(builder.edges_builder.builder.includes?).to eq(true)
        expect(builder.edges_builder.builder.included_path).to eq([:edges_a])
        expect(builder.edges_builder.builder.active_record_includes).to eq([:edges_a])

        expect(builder.edges_builder.node_builder.includes?).to eq(true)
        expect(builder.edges_builder.node_builder.included_path).to eq([:node_on_edge_a])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq([:node_on_edge_a])
      end
    end

    context 'with deep nesting' do
      it 'generates the correct includes pattern' do
        builder = subject
        builder.nodes(:through_something, :to, :nodes_a)
        builder.edges do
          path(:through_something)
          node(:node_on_edge_a)
        end

        expect(builder.includes?).to eq(true)
        expect(builder.nodes_builder.includes?).to eq(true)
        expect(builder.nodes_builder.included_path).to eq([:through_something, :to, :nodes_a])
        expect(builder.nodes_builder.active_record_includes).to eq({ through_something: { to: [:nodes_a] } })

        expect(builder.edges_builder.builder.includes?).to eq(true)
        expect(builder.edges_builder.builder.included_path).to eq([:through_something])
        expect(builder.edges_builder.builder.active_record_includes).to eq([:through_something])

        expect(builder.edges_builder.node_builder.includes?).to eq(true)
        expect(builder.edges_builder.node_builder.included_path).to eq([:node_on_edge_a])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq([:node_on_edge_a])
      end
    end

    context 'with siblings' do
      it 'generates the correct includes pattern' do
        builder = subject
        builder.nodes(:nodes_a)
        builder.edges do
          path(:edges_a)
          sibling_path(:other_association_for_edges) do
            path(:that_goes_deeper)
          end
          node(:node_on_edge_a)
        end

        expect(builder.includes?).to eq(true)
        expect(builder.nodes_builder.includes?).to eq(true)
        expect(builder.nodes_builder.included_path).to eq([:nodes_a])
        expect(builder.nodes_builder.active_record_includes).to eq([:nodes_a])

        expect(builder.edges_builder.builder.includes?).to eq(true)
        expect(builder.edges_builder.builder.included_path).to eq([:edges_a])
        expect(builder.edges_builder.builder.active_record_includes).to eq([:edges_a, { other_association_for_edges: [:that_goes_deeper] }])

        expect(builder.edges_builder.node_builder.includes?).to eq(true)
        expect(builder.edges_builder.node_builder.included_path).to eq([:node_on_edge_a])
        expect(builder.edges_builder.node_builder.active_record_includes).to eq([:node_on_edge_a])
      end
    end
  end
end
