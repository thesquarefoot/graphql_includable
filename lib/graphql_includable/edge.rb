module GraphQLIncludable
  class Edge < GraphQL::Relay::Edge
    # edge_record represents the data in between `node` and `parent`,
    # basically the `through` record in a has-many-through association
    # @returns record ActiveRecord::Base
    def edge_record
      @edge_record ||= edge_record_from_memory || edge_record_from_database
    end

    # attempt to query the edge record freshly from the database
    # @returns record ActiveRecord::Base
    def edge_record_from_database
      first_association, *nested_associations = associations_between_node_and_parent
      edge_class = self.class.str_to_class(first_association)
      root_association_key = root_association_key(edge_class)

      selector = edge_class

      if nested_associations.present?
        nested_association_names = nested_associations.map { |s| s.to_s.singularize }
        selector = selector.merge(edge_class.includes(*nested_association_names))
      end

      if class_is_polymorphic?(edge_class)
        selector = selector.merge(edge_class.joins(root_association_key))
      end

      selector.find_by(
        where_hash_for_edge(root_association_key, nested_associations)
      )
    end

    # attempt to pull the preloaded edge record out of the associated object in memory
    # @returns record ActiveRecord::Base
    def edge_record_from_memory
      associations = associations_between_node_and_parent
      records = associations.reverse.reduce(parent) { |acc, cur| acc.send(cur) }
      return unless records.loaded?
      records.first do |rec|
        child_association_name = node.class.name.downcase.to_sym
        rec.send(root_association_key) == parent && rec.send(child_association_name) == node
      end
    end

    def class_is_polymorphic?(klass)
      klass.reflections.any? { |_k, r| r.polymorphic? }
    end

    # Delegate method calls on this Edge instance to the ActiveRecord instance
    def method_missing(method_name, *args, &block)
      return super unless edge_record.respond_to?(method_name)
      edge_record.send(method_name, *args, &block)
    end

    def respond_to_missing?(method_name, include_private = false)
      edge_record.respond_to?(method_name) || super
    end

    private

    # List all HasManyThrough associations between node and parent models
    # @returns associations Array<Symbol>
    def associations_between_node_and_parent
      return @associations if @associations.present?

      associations = []
      association_name = node.class.name.pluralize.downcase.to_sym
      association = parent.class.reflect_on_association(association_name)
      while association.is_a?(ActiveRecord::Reflection::ThroughReflection)
        associations.unshift(association.options[:through])
        association = parent.class.reflect_on_association(association.options[:through])
      end

      @associations = associations
    end

    # List the key:value criteria for finding the edge record in the database
    # @param root_key Symbol
    # @param nested_associations Array<Symbol>
    # @returns where_hash Hash<?>
    def where_hash_for_edge(root_key, nested_associations)
      root_include = { root_key => [parent] }
      terminal_include = { self.class.class_to_str(node.class) => node }
      inner_includes = nested_associations.reverse.reduce(terminal_include) do |acc, rel_name|
        { rel_name.to_s.pluralize => acc }
      end
      root_include.merge(inner_includes)
    end

    # @param edge_class ActiveRecord::Base
    # @returns key Symbol
    def root_association_key(edge_class)
      key = self.class.class_to_str(parent.class)
      unless edge_class.reflections.keys.include?(key)
        key = edge_class.reflections.select { |_k, r| r.polymorphic? }.keys.first
      end
      key.to_sym
    end

    class << self
      # @param str String
      # @returns klass Class
      def str_to_class(str)
        str.to_s.singularize.camelize.constantize
      rescue # rubocop:disable Lint/HandleExceptions
      end

      # @param klass Class
      # @returns str String
      def class_to_str(klass)
        klass.name.downcase
      end
    end
  end
end
