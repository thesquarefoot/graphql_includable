module GraphQLIncludable
  class Edge < GraphQL::Relay::Edge
    def method_missing(sym, *args, &block)
      get_single_record(sym) || super
    end

    def respond_to_missing?(sym, include_private = false)
      !get_association(sym).nil? || super
    end

    private

    def get_association(sym)
      association_name = sym.to_s.pluralize.to_sym
      parent.class.reflect_on_association(association_name)
    end

    def get_single_record(sym)
      association = get_association(sym)
      return unless association
      target_class = node.class
      target_association_name = target_class.name.singularize.downcase
      node_id = node[target_class.primary_key]
      foreign_key = association.klass.reflect_on_association(target_association_name).foreign_key
      parent.method(association.name).call.find do |record|
        record[foreign_key] == node_id
      end
    end
  end
end
