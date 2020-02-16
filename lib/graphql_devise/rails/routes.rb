module ActionDispatch::Routing
  class Mapper
    DEVISE_OPERATIONS = [
      :sessions,
      :registrations,
      :passwords,
      :confirmations,
      :omniauth_callbacks,
      :unlocks,
      :invitations
    ].freeze

    def mount_graphql_devise_for(resource, opts = {})
      custom_operations    = opts.fetch(:operations, {})
      skipped_operations   = opts.fetch(:skip, [])
      only_operations      = opts.fetch(:only, [])
      additional_mutations = opts.fetch(:additional_mutations, {})
      additional_queries   = opts.fetch(:additional_queries, {})
      path                 = opts.fetch(:at, '/graphql_auth')
      mapping_name         = resource.underscore.tr('/', '_').to_sym
      authenticatable_type = opts[:authenticatable_type].presence ||
        "Types::#{resource}Type".safe_constantize ||
        GraphqlDevise::Types::AuthenticatableType
      param_operations     = {
        custom:  custom_operations,
        only:    only_operations,
        skipped: skipped_operations
      }

      validate_operations!(param_operations)

      devise_for(
        resource.pluralize.underscore.tr('/', '_').to_sym,
        module: :devise,
        skip:   [DEVISE_OPERATIONS]
      )

      prepared_mutations = GraphqlDevise::MutationsPreparer.call(
        resource:             resource,
        mutations:            GraphqlDevise::OperationSanitizer.call(
          default: default_mutations, **param_operations
        ),
        authenticatable_type: authenticatable_type
      )

      prepared_queries = GraphqlDevise::QueriesPreparer.call(
        resource:             resource,
        queries:              GraphqlDevise::OperationSanitizer.call(
          default: default_queries, **param_operations
        ),
        authenticatable_type: authenticatable_type
      )

      add_mutations!(prepared_mutations, additional_mutations)
      add_queries!(prepared_queries, additional_queries)

      Devise.mailer.helper(GraphqlDevise::MailerHelper)

      devise_scope mapping_name do
        post path, to: 'graphql_devise/graphql#auth'
        get  path, to: 'graphql_devise/graphql#auth'
      end
    end

    private

    def default_mutations
      {
        login:               GraphqlDevise::Mutations::Login,
        logout:              GraphqlDevise::Mutations::Logout,
        sign_up:             GraphqlDevise::Mutations::SignUp,
        update_password:     GraphqlDevise::Mutations::UpdatePassword,
        send_password_reset: GraphqlDevise::Mutations::SendPasswordReset,
        resend_confirmation: GraphqlDevise::Mutations::ResendConfirmation
      }
    end

    def default_queries
      {
        confirm_account:      GraphqlDevise::Resolvers::ConfirmAccount,
        check_password_token: GraphqlDevise::Resolvers::CheckPasswordToken
      }
    end

    def validate_operations!(param_operations)
      GraphqlDevise::OperationChecker.call(
        mutations: default_mutations,
        queries:   default_queries,
        **param_operations
      )
    end

    def add_mutations!(prepared, additional)
      all_mutations = prepared.merge(additional)

      all_mutations.each do |action, mutation|
        GraphqlDevise::Types::MutationType.field(action, mutation: mutation)
      end

      if all_mutations.present? &&
         (Gem::Version.new(GraphQL::VERSION) <= Gem::Version.new('1.10.0') || GraphqlDevise::Schema.mutation.nil?)
        GraphqlDevise::Schema.mutation(GraphqlDevise::Types::MutationType)
      end
    end

    def add_queries!(prepared, additional)
      prepared.merge(additional).each do |action, resolver|
        GraphqlDevise::Types::QueryType.field(action, resolver: resolver)
      end

      if (prepared.blank? || additional.present?) && GraphqlDevise::Types::QueryType.fields.blank?
        GraphqlDevise::Types::QueryType.field(:dummy, resolver: GraphqlDevise::Resolvers::Dummy)
      end
    end
  end
end
