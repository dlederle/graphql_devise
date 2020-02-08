module GraphqlDevise
  class OperationSanitizer
    def self.call(resource:, default:, custom:, only:, skipped:)
      new(
        resource: resource,
        default:  default,
        custom:   custom,
        only:     only,
        skipped:  skipped
      ).call
    end

    def initialize(resource:, default:, custom:, only:, skipped:)
      @resource   = resource
      @mapping    = resource.underscore.tr('/', '_').to_sym
      @default    = default
      @custom     = custom
      @only       = only
      @skipped    = skipped
    end

    def call
      result = @default
      result = result.merge(@custom.slice(*operations_whitelist))
      result = result.slice(*@only) if @only.present?
      result = result.except(*@skipped) if @skipped.present?

      result.transform_keys { |k| "#{@mapping}_#{k}".to_sym }
    end

    private

    def operations_whitelist
      @default.keys
    end
  end
end
