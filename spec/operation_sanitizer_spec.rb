require 'rails_helper'

RSpec.describe GraphqlDevise::OperationSanitizer do
  describe '.call' do
    subject(:result) do
      described_class.call(
        resource: resource,
        default:  default,
        custom:   custom,
        only:     only,
        skipped:  skipped
      )
    end

    context 'when the operations passed are mutations' do
      let(:resource) { 'User' }
      let(:custom)   { {} }
      let(:skipped)  { [] }
      let(:only)     { [] }
      let(:default) do
        {
          login:               GraphqlDevise::Mutations::Login,
          logout:              GraphqlDevise::Mutations::Logout,
          sign_up:             GraphqlDevise::Mutations::SignUp,
          update_password:     GraphqlDevise::Mutations::UpdatePassword,
          send_password_reset: GraphqlDevise::Mutations::SendPasswordReset,
          resend_confirmation: GraphqlDevise::Mutations::ResendConfirmation
        }
      end

      context 'when no other option besides default is passed' do
        it 'returns all the default operations appending mapping to the key' do
          expect(result).to eq(
            user_login:               GraphqlDevise::Mutations::Login,
            user_logout:              GraphqlDevise::Mutations::Logout,
            user_sign_up:             GraphqlDevise::Mutations::SignUp,
            user_update_password:     GraphqlDevise::Mutations::UpdatePassword,
            user_send_password_reset: GraphqlDevise::Mutations::SendPasswordReset,
            user_resend_confirmation: GraphqlDevise::Mutations::ResendConfirmation
          )
        end
      end

      context 'when there are custom operations' do
        let(:custom) do
          {
            login:   Mutations::Login,
            sign_up: Mutations::SignUp,
            query:   GraphQL::Schema::Resolver
          }
        end

        it 'returns the default ops replacing the custom ones appending mapping to the key' do
          expect(result).to eq(
            user_login:               Mutations::Login,
            user_logout:              GraphqlDevise::Mutations::Logout,
            user_sign_up:             Mutations::SignUp,
            user_update_password:     GraphqlDevise::Mutations::UpdatePassword,
            user_send_password_reset: GraphqlDevise::Mutations::SendPasswordReset,
            user_resend_confirmation: GraphqlDevise::Mutations::ResendConfirmation
          )
        end
      end

      context 'when there are only operations' do
        let(:only) { [:sign_up, :update_password] }

        it 'returns only those default ops appending mapping to the key' do
          expect(result).to eq(
            user_sign_up:         GraphqlDevise::Mutations::SignUp,
            user_update_password: GraphqlDevise::Mutations::UpdatePassword
          )
        end
      end

      context 'when there are skipped operations' do
        let(:skipped) { [:sign_up, :update_password] }

        it 'returns the default ops but the skipped appending mapping to the key' do
          expect(result).to eq(
            user_login:               GraphqlDevise::Mutations::Login,
            user_logout:              GraphqlDevise::Mutations::Logout,
            user_send_password_reset: GraphqlDevise::Mutations::SendPasswordReset,
            user_resend_confirmation: GraphqlDevise::Mutations::ResendConfirmation
          )
        end
      end
    end
  end
end
