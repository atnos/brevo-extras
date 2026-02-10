[![CI](https://github.com/atnos/brevo-extras/actions/workflows/ci.yml/badge.svg)](https://github.com/atnos/brevo-extras/actions/workflows/ci.yml)
[![CodeQL](https://github.com/atnos/brevo-extras/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/atnos/brevo-extras/actions/workflows/github-code-scanning/codeql)
[![Dependabot Updates](https://github.com/atnos/brevo-extras/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/atnos/brevo-extras/actions/workflows/dependabot/dependabot-updates)

# Brevo::Extras

A Rails engine that provides a clean abstraction layer for sending transactional emails via the [Brevo](https://www.brevo.com/) API, with built-in safety features to prevent accidental email delivery in development and test environments.

## Features

- Abstract base class for creating email sender classes
- Asynchronous delivery via Active Job
- Automatic retry on API errors with polynomial backoff
- **Sandbox mode** - prevents actual email delivery (enabled by default)
- **Safe mode** - filters recipients by allowed domains (enabled by default in local environments)
- Template-based emails with parameters
- Reply-to address support

## Installation

Add this line to your application's Gemfile:

```ruby
gem "brevo-extras"
```

And then execute:

```bash
$ bundle
```

## Configuration

The engine is configured through environment variables:

| Variable | Default | Description |
|---|---|---|
| `BREVO_SANDBOX_MODE` | `"1"` | When enabled, adds `X-Sib-Sandbox: drop` header so Brevo accepts the request but does not send the email |
| `BREVO_SAFE_MODE` | `"1"` | When enabled, filters recipients to only allowed domains. Always active in local Rails environments (`development`, `test`) regardless of this setting |
| `BREVO_SAFE_MODE_ALLOWED_DOMAINS` | `""` | Comma-separated list of allowed email domains (e.g. `"example.com,mycompany.com"`) |

You also need to configure the Brevo API key as required by the [brevo gem](https://github.com/getbrevo/brevo-ruby).

## Usage

### Creating an email sender

Subclass `Brevo::Extras::Base` and implement the `#call` method:

```ruby
class WelcomeEmail < Brevo::Extras::Base
  def call
    send_email(
      template_id: 1,
      to: [{ email: params[:email], name: params[:name] }]
    )
  end
end
```

### Sending an email

```ruby
WelcomeEmail.call(email: "user@example.com", name: "John")
```

The email is enqueued as an Active Job and delivered asynchronously.

### Reply-to support

```ruby
send_email(
  template_id: 1,
  to: [{ email: params[:email], name: params[:name] }],
  reply_to: { email: "support@example.com" }
)
```

### Template parameters

Parameters passed to `.call` are forwarded to the Brevo template as `params`:

```ruby
# These params will be available in your Brevo template
OrderConfirmation.call(
  email: "user@example.com",
  order_id: "12345",
  total: "$99.00"
)
```

### Retry behavior

The `DeliveryJob` automatically retries on `Brevo::ApiError` with polynomial backoff, up to 5 attempts.

## Development

### Running tests

```bash
bin/rails test
```

### Linting

```bash
bin/rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
