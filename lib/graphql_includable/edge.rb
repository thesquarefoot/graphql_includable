module GraphQLIncludable
  class Edge < GraphQL::Relay::Edge
    def edge
      join_chain = joins_along_edge
      edge_class_name = join_chain.shift
      edge_class = str_to_class(edge_class_name)

      root_node = { class_to_str(parent.class).to_s.singularize => parent }
      terminal_node = { class_to_str(node.class).singularize => node }
      join_chain.reverse.each do |rel_name|
        terminal_node = { rel_name.to_s.pluralize => terminal_node }
      end
      search_hash = root_node.merge(terminal_node)
      edge_includes = join_chain.map { |s| s.to_s.singularize }
      edge_class = edge_class.includes(*edge_includes) unless edge_includes.empty?
      @edge ||= edge_class.find_by(search_hash)
    end

    def method_missing(method_name, *args, &block)
      if edge.respond_to?(method_name)
        edge.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing(method_name, include_private = false)
      edge.respond_to?(method_name) || super
    end

    private

    def str_to_class(str)
      str.to_s.singularize.camelize.constantize
    rescue
    end

    def class_to_str(klass)
      klass.name.pluralize.downcase
    end

    def joins_along_edge
      join_chain = []
      starting_class = parent.class
      node_relationship_name = class_to_str(node.class)
      while starting_class
        reflection = starting_class.reflect_on_association(node_relationship_name)
        association_name = reflection&.options&.try(:[], :through)
        join_chain << association_name if association_name
        starting_class = str_to_class(association_name)
        node_relationship_name = node_relationship_name.singularize
      end
      join_chain
    end
  end
end
