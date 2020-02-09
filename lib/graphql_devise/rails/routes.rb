module ActionDispatch::Routing
  class Mapper
    def mount_graphql_devise_for(resource, opts = {})
      custom_operations    = opts.fetch(:operations, {})
      skipped_operations   = opts.fetch(:skip, [])
      only_operations      = opts.fetch(:only, [])
      additional_mutations = opts.fetch(:additional_mutations, {})
      additional_queries   = opts.fetch(:additional_queries, {})

      # if [skipped_operations, only_operations].all?(&:any?)
      #   raise GraphqlDevise::Error, "Can't specify both `skip` and `only` options when mounting the route."
      # end

      default_mutations = {
        login:               GraphqlDevise::Mutations::Login,
        logout:              GraphqlDevise::Mutations::Logout,
        sign_up:             GraphqlDevise::Mutations::SignUp,
        update_password:     GraphqlDevise::Mutations::UpdatePassword,
        send_password_reset: GraphqlDevise::Mutations::SendPasswordReset,
        resend_confirmation: GraphqlDevise::Mutations::ResendConfirmation
      }#.freeze
      default_queries = {
        confirm_account:      GraphqlDevise::Resolvers::ConfirmAccount,
        check_password_token: GraphqlDevise::Resolvers::CheckPasswordToken
      }
      # supported_operations = default_mutations.keys + default_queries.keys

      # unless skipped_operations.all? { |skipped| supported_operations.include?(skipped) }
      #   raise GraphqlDevise::Error, 'Trying to skip a non supported operation. Check for typos.'
      # end
      # unless only_operations.all? { |only| supported_operations.include?(only) }
      #   raise GraphqlDevise::Error, 'One of the `only` operations is not supported. Check for typos.'
      # end

      GraphqlDevise::OperationChecker.call(
        mutations: default_mutations,
        queries:   default_queries,
        custom:    custom_operations,
        only:      only_operations,
        skipped:   skipped_operations
      )

      path         = opts.fetch(:at, '/graphql_auth')
      mapping_name = resource.underscore.tr('/', '_').to_sym

      devise_for(
        resource.pluralize.underscore.tr('/', '_').to_sym,
        module: :devise,
        skip:   [:sessions, :registrations, :passwords, :confirmations, :omniauth_callbacks, :unlocks, :invitations]
      )

      authenticatable_type = opts[:authenticatable_type] ||
        "Types::#{resource}Type".safe_constantize ||
        GraphqlDevise::Types::AuthenticatableType

      # used_mutations = if only_operations.present?
      #   default_mutations.slice(*only_operations)
      # else
      #   default_mutations.except(*skipped_operations)
      # end
      # used_mutations.each do |action, mutation|
      #   used_mutation = if custom_operations[action].present?
      #     custom_operations[action]
      #   else
      #     new_mutation = Class.new(mutation)
      #     new_mutation.graphql_name("#{resource}#{action.to_s.camelize(:upper)}")
      #     new_mutation.field(:authenticatable, authenticatable_type, null: true)

      #     new_mutation
      #   end
      #   used_mutation.instance_variable_set(:@resource_name, mapping_name)

      #   GraphqlDevise::Types::MutationType.field("#{mapping_name}_#{action}", mutation: used_mutation)
      # end
      used_mutations = GraphqlDevise::OperationSanitizer.call(
        default: default_mutations,
        custom:  custom_operations,
        only:    only_operations,
        skipped: skipped_operations
      )
      prepared_mutations = GraphqlDevise::MutationsPreparer.call(
        resource:             resource,
        mutations:            used_mutations,
        authenticatable_type: authenticatable_type
      )

      (additional_mutations + prepared_mutations).each do |action, mutation|
        GraphqlDevise::Types::MutationType.field(action, mutation: mutation)
      end

      if (used_mutations.present? || additional_mutations.present?) &&
         (Gem::Version.new(GraphQL::VERSION) <= Gem::Version.new('1.10.0') || GraphqlDevise::Schema.mutation.nil?)
        GraphqlDevise::Schema.mutation(GraphqlDevise::Types::MutationType)
      end

      used_queries = if only_operations.present?
        default_queries.slice(*only_operations)
      else
        default_queries.except(*skipped_operations)
      end
      used_queries.each do |action, query|
        used_query = if custom_operations[action].present?
          custom_operations[action]
        else
          new_query = Class.new(query)
          new_query.graphql_name("#{resource}#{action.to_s.camelize(:upper)}")
          new_query.type(authenticatable_type, null: true)

          new_query
        end
        used_query.instance_variable_set(:@resource_name, mapping_name)

        GraphqlDevise::Types::QueryType.field("#{mapping_name}_#{action}", resolver: used_query)
      end
      additional_queries.each do |action, resolver|
        GraphqlDevise::Types::QueryType.field(action, resolver: resolver)
      end

      if (used_queries.blank? || additional_queries.present?) && GraphqlDevise::Types::QueryType.fields.blank?
        GraphqlDevise::Types::QueryType.field(:dummy, resolver: GraphqlDevise::Resolvers::Dummy)
      end

      Devise.mailer.helper(GraphqlDevise::MailerHelper)

      devise_scope mapping_name do
        post path, to: 'graphql_devise/graphql#auth'
        get  path, to: 'graphql_devise/graphql#auth'
      end
    end
  end
end
