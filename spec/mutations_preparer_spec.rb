require 'rails_helper'

RSpec.describe GraphqlDevise::MutationsPreparer do
  describe '.call' do
    subject do
      described_class.call(
        resource:             resource,
        mutations:            mutations,
        authenticatable_type: auth_type
      )
    end

    let(:resource)   { 'User' }
    let(:class_1)    { Class.new(GraphqlDevise::Types::MutationType) }
    let(:class_2)    { Class.new(GraphqlDevise::Types::MutationType) }
    let(:auth_type)  { GraphqlDevise::Types::AuthenticatableType }
    let(:mutations)  { { mutation_1: class_1, mutation_2: class_2 } }

    context 'when mutations is *NOT* empty' do
      it 'assign gql attibutes to mutations and changes keys using resource map' do
        result = subject

        expect(result.keys).to contain_exactly(:user_mutation_1, :user_mutation_2)
        expect(result.values.map(&:graphql_name)).to contain_exactly('UserMutation1', 'UserMutation2')
      end
    end

    context 'when mutations is empty' do
      let(:operations) { {} }

      it { is_expected.to be_empty }
    end
  end
end
