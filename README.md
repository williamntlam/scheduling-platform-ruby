# Appointments & Scheduling Platform — Implementation Guide (Rails + OOP + Patterns)

> A practical, extensible Rails project that emphasizes clean OOP design and classic patterns (Strategy, State, Command, Factory/Adapter, Template Method, Specification, Decorator, Observer). This guide is opinionated and step‑by‑step, with **skeletons and method signatures** so you can implement the logic yourself.

---

## 0) Goals & Scope

- **Domain**: Services (e.g., yoga class, guitar lesson), Providers, Customers, Time Slots, Bookings, Payments, Add‑ons.
- **Focus**: Testable domain layer of POROs; thin controllers; AR models for persistence only.
- **Patterns**:  
  - Strategy (pricing, cancellation, allocation)  
  - State (booking lifecycle)  
  - Command (use‑cases)  
  - Factory/Adapter (payments/calendar)  
  - Template Method (notifications/receipts)  
  - Specification (search filters)  
  - Decorator (compose pricing components)  
  - Observer (events → side effects)

---

## 1) Project Setup

```bash
rails new scheduler_api --api -T
cd scheduler_api

# Recommended gems (add to Gemfile manually)
# gem 'rspec-rails'
# gem 'factory_bot_rails'
# gem 'faker'
# gem 'sidekiq'      # if using background jobs
# gem 'dotenv-rails' # env management in dev/test

bundle install
rails g rspec:install
```

**Autoloading**: Put domain POROs under `app/domain/**` and commands under `app/commands/**`. Rails (Zeitwerk) will autoload them by default.

---

## 2) High-Level Architecture

```
app/
  controllers/       # Thin; orchestrate commands; render JSON
  models/            # AR models: persistence, validations, simple scopes
  commands/          # Use-cases wrapping transactions + events
  domain/            # Pure Ruby: strategies, states, value objects, adapters
    value_objects/
    pricing/
      strategies/
    cancellation/
      strategies/
    booking_state/
    booking/
      decorators/
    payments/
      providers/
    notifications/
    search/
      specifications/
    calendar/
      adapters/
  subscribers/       # Event subscribers
```

**Principles**:
- Models are skinny; avoid complex callbacks.  
- Orchestration lives in **commands**.  
- Business rules live in **domain** POROs.  
- Side effects (emails, analytics) via **events** and **subscribers**.

---

## 3) Data Model (Entities & Fields)

### 3.1 ActiveRecord Models (suggested fields)

**User**
- `email:string:index`
- `name:string`
- `role:string` (enum: `customer`, `provider`, `admin`)
- Timestamps

**Service**
- `name:string`
- `description:text`
- `base_price_cents:integer` (store money in cents)
- `duration_minutes:integer`
- `active:boolean` (default: true)
- Timestamps

**Location**
- `name:string`
- `line1:string`
- `city:string`
- `country:string`
- `postal_code:string`
- Timestamps

**ScheduleSlot**
- `service:references`
- `provider:references{to:users}`
- `location:references`
- `starts_at:datetime`
- `ends_at:datetime`
- `capacity:integer` (>= 1)
- `active:boolean` (default: true)
- Timestamps

**Booking**
- `customer:references{to:users}`
- `service:references`
- `schedule_slot:references`
- `state:string` (state machine)
- `price_cents:integer` (final computed price)
- `currency:string` (e.g., "USD")
- `cancellation_fee_cents:integer` (nullable)
- `canceled_reason:string` (nullable)
- Timestamps

**AddOn**
- `name:string`
- `price_cents:integer`
- `active:boolean` (default: true)
- Timestamps

**BookingAddOn** (join)
- `booking:references`
- `add_on:references`
- `quantity:integer` (default: 1)
- Timestamps

**Payment**
- `booking:references`
- `provider:string` (e.g., `stripe`)
- `status:string` (enum: `created`, `authorized`, `captured`, `failed`, `refunded`)
- `amount_cents:integer`
- `external_ref:string`
- Timestamps

### 3.2 Generators (you run)
```bash
rails g model User email:string name:string role:string
rails g model Service name:string description:text base_price_cents:integer duration_minutes:integer active:boolean
rails g model Location name:string line1:string city:string country:string postal_code:string
rails g model ScheduleSlot service:references provider:references{to:users} location:references starts_at:datetime ends_at:datetime capacity:integer active:boolean
rails g model Booking customer:references{to:users} service:references schedule_slot:references state:string price_cents:integer currency:string cancellation_fee_cents:integer canceled_reason:string
rails g model AddOn name:string price_cents:integer active:boolean
rails g model BookingAddOn booking:references add_on:references quantity:integer
rails g model Payment booking:references provider:string status:string amount_cents:integer external_ref:string
rails db:migrate
```

> Add validations and indexes in migrations as needed (e.g., `add_index :users, :email, unique: true`).

---

## 4) Value Objects (POROs)

`app/domain/value_objects/money.rb`
```ruby
module ValueObjects
  class Money
    attr_reader :cents, :currency

    def initialize(cents:, currency: "USD")
      # TODO: guard invariants (integer cents, supported currency)
      @cents = cents
      @currency = currency
    end

    def +(other) = self.class.new(cents: cents + other.cents, currency: currency)
    def -(other) = self.class.new(cents: cents - other.cents, currency: currency)

    def multiply(factor)
      # TODO: rounding policy
      raise NotImplementedError
    end

    def to_s
      # TODO: format (e.g., "$12.34")
      raise NotImplementedError
    end
  end
end
```

`app/domain/value_objects/time_range.rb`
```ruby
module ValueObjects
  class TimeRange
    attr_reader :starts_at, :ends_at

    def initialize(starts_at:, ends_at:)
      # TODO: assert starts_at < ends_at
      @starts_at, @ends_at = starts_at, ends_at
    end

    def overlaps?(other)
      # TODO
      raise NotImplementedError
    end

    def duration_minutes
      # TODO
      raise NotImplementedError
    end
  end
end
```

`app/domain/value_objects/capacity.rb`
```ruby
module ValueObjects
  class Capacity
    def initialize(limit:)
      # TODO: assert limit >= 1
      @limit = limit
    end

    def fits?(current_count, requested = 1)
      # TODO
      raise NotImplementedError
    end
  end
end
```

---

## 5) Pricing (Strategy + Decorator)

`app/domain/pricing/price_calculator.rb`
```ruby
module Pricing
  class PriceCalculator
    def initialize(strategies: [])
      @strategies = strategies
    end

    def total(base_money:, context: {})
      # TODO: fold strategies to compute final Money
      raise NotImplementedError
    end
  end
end
```

`app/domain/pricing/strategies/base_rate.rb`
```ruby
module Pricing
  module Strategies
    class BaseRate
      def call(base_money:, context:)
        # TODO: typically identity
        raise NotImplementedError
      end
    end
  end
end
```

`app/domain/pricing/strategies/peak_hour_surge.rb`
```ruby
module Pricing
  module Strategies
    class PeakHourSurge
      def initialize(multiplier: 1.25) # e.g., 25% surge
        @multiplier = multiplier
      end

      def call(base_money:, context:)
        # TODO: apply only if context[:peak_hour] == true
        raise NotImplementedError
      end
    end
  end
end
```

`app/domain/pricing/strategies/member_discount.rb`
```ruby
module Pricing
  module Strategies
    class MemberDiscount
      def initialize(percent_off: 0.10)
        @percent_off = percent_off
      end

      def call(base_money:, context:)
        # TODO: apply for members in context
        raise NotImplementedError
      end
    end
  end
end
```

### Booking Price Decorators (`app/domain/booking/decorators/*`)
- `WithAddons`: adds addon prices to base
- `WithTax`: apply tax rule
- `WithSurge`: apply surge

```ruby
module Booking
  module Decorators
    class WithAddons
      def initialize(priceable, addons: [])
        @priceable = priceable
        @addons = addons
      end

      def total_money(context: {})
        # TODO: base + sum(addons)
        raise NotImplementedError
      end

      def breakdown
        # TODO: return array of line items
        raise NotImplementedError
      end
    end
  end
end
```

---

## 6) Cancellation (Strategy)

`app/domain/cancellation/strategies/no_fee_before_window.rb`
```ruby
module Cancellation
  module Strategies
    class NoFeeBeforeWindow
      def initialize(hours: 24)
        @hours = hours
      end

      def fee(booking:, now: Time.current)
        # TODO: 0 if canceled earlier than @hours
        raise NotImplementedError
      end
    end
  end
end
```

`app/domain/cancellation/strategies/percentage_after_window.rb`
```ruby
module Cancellation
  module Strategies
    class PercentageAfterWindow
      def initialize(hours: 24, percent: 0.5)
        @hours, @percent = hours, percent
      end

      def fee(booking:, now: Time.current)
        # TODO: percent of price if inside window, else 0
        raise NotImplementedError
      end
    end
  end
end
```

---

## 7) Booking Lifecycle (State Pattern)

`app/domain/booking_state/base_state.rb`
```ruby
module BookingState
  class BaseState
    def initialize(booking)
      @booking = booking
    end

    # Transition methods:
    def confirm!;       raise NotImplementedError end
    def cancel!(reason: nil); raise NotImplementedError end
    def complete!;      raise NotImplementedError end
    def check_in!;      raise NotImplementedError end

    def name;           self.class.name.demodulize.underscore.to_sym end
  end
end
```

Concrete states (one file each): `draft.rb`, `confirmed.rb`, `canceled.rb`, `completed.rb`, `no_show.rb`.

Example skeleton:
```ruby
module BookingState
  class Draft < BaseState
    def confirm!
      # TODO: allowed → persist booking.state = 'confirmed'
      raise NotImplementedError
    end

    def cancel!(reason:)
      # TODO
      raise NotImplementedError
    end
  end
end
```

> In `Booking` AR model, add helper to resolve state object:
```ruby
def state_object
  # TODO: map state string to class, e.g., BookingState::Draft.new(self)
  raise NotImplementedError
end
```

---

## 8) Payments (Factory / Adapter)

`app/domain/payments/factory.rb`
```ruby
module Payments
  class Factory
    def self.build(provider_code)
      case provider_code.to_s
      when "fake"   then Providers::Fake.new
      when "stripe" then Providers::Stripe.new(api_key: ENV["STRIPE_KEY"])
      else
        raise ArgumentError, "Unknown provider: #{provider_code}"
      end
    end
  end
end
```

`app/domain/payments/providers/fake.rb`
```ruby
module Payments
  module Providers
    class Fake
      def authorize(amount_cents:, currency:, metadata: {})
        # TODO: return a fake ref
        raise NotImplementedError
      end
      def capture(external_ref:)
        # TODO
        raise NotImplementedError
      end
      def refund(external_ref:, amount_cents:)
        # TODO
        raise NotImplementedError
      end
    end
  end
end
```

(Stripe adapter is similar; leave unimplemented for now.)

---

## 9) Notifications (Template Method)

`app/domain/notifications/base_renderer.rb`
```ruby
module Notifications
  class BaseRenderer
    def render(booking:)
      {
        subject: subject(booking:),
        body: body(booking:)
      }
    end

    protected

    def subject(booking:); raise NotImplementedError end
    def body(booking:);    raise NotImplementedError end
  end
end
```

`email_renderer.rb` / `sms_renderer.rb` override `subject`/`body` with different formatting.

---

## 10) Search (Specification + Query Object)

`app/domain/search/specifications/base_specification.rb`
```ruby
module Search
  module Specifications
    class BaseSpecification
      def apply(scope)
        # TODO: default returns scope
        raise NotImplementedError
      end
    end
  end
end
```

Specific specs: `by_service.rb`, `by_location.rb`, `by_time_range.rb`, `by_capacity.rb`.  
`available_slots_query.rb` composes specs:

```ruby
module Search
  class AvailableSlotsQuery
    def initialize(specs: [])
      @specs = specs
    end

    def call(relation = ScheduleSlot.all)
      @specs.reduce(relation) { |scope, spec| spec.apply(scope) }
    end
  end
end
```

---

## 11) Commands (Use-Cases)

`app/commands/book_slot.rb`
```ruby
class BookSlot
  Result = Struct.new(:booking, :errors, keyword_init: true)

  def initialize(customer:, slot_id:, add_on_ids: [])
    @customer, @slot_id, @add_on_ids = customer, slot_id, add_on_ids
  end

  def call
    Booking.transaction do
      # 1) load slot, service, check capacity
      # 2) build booking + add-ons
      # 3) price via Pricing::PriceCalculator (+ decorators if used)
      # 4) persist booking
      # 5) emit 'booking.created' event
      # return Result
      raise NotImplementedError
    end
  rescue => e
    # return Result with errors
    raise NotImplementedError
  end
end
```

`cancel_booking.rb`, `reschedule_booking.rb`, `capture_payment.rb`, `check_in_booking.rb` follow the same pattern: encapsulate validation, DB transaction, and events.

---

## 12) Controllers (Thin, JSON)

`app/controllers/bookings_controller.rb`
```ruby
class BookingsController < ApplicationController
  def create
    # params: { service_id, slot_id, add_on_ids: [], customer_id }
    # invoke BookSlot → render JSON
    # TODO
  end

  def show
    # load booking → presenter → render JSON
    # TODO
  end

  def update
    # optional: mutate add-ons/notes
    # TODO
  end

  def cancel
    # CancelBooking command
    # TODO
  end

  def reschedule
    # RescheduleBooking command
    # TODO
  end
end
```

`app/controllers/services_controller.rb`, `slots_controller.rb`, `payments_controller.rb` implement similar thin actions.

**Routes (`config/routes.rb`)**
```ruby
Rails.application.routes.draw do
  resources :services, only: %i[index show]
  resources :slots, only: %i[index]
  resources :bookings, only: %i[create show update] do
    member do
      patch :cancel
      patch :reschedule
    end
  end
  resources :payments, only: %i[create] # capture/confirm
end
```

---

## 13) JSON Contracts (Examples)

**GET `/slots?service_id=1&date=2025-08-21&location_id=2` → 200**
```json
[
  {
    "id": 42,
    "service_id": 1,
    "provider_id": 9,
    "location_id": 2,
    "starts_at": "2025-08-21T15:00:00Z",
    "ends_at": "2025-08-21T15:30:00Z",
    "capacity": 8,
    "available": 3
  }
]
```

**POST `/bookings` (request)**
```json
{
  "customer_id": 10,
  "slot_id": 42,
  "add_on_ids": [3, 5]
}
```

**POST `/bookings` (response)**
```json
{
  "id": 99,
  "state": "confirmed",
  "price_cents": 4500,
  "currency": "USD",
  "addons": [
    {"id": 3, "name": "Mat Rental", "price_cents": 300},
    {"id": 5, "name": "Premium Equipment", "price_cents": 700}
  ]
}
```

**PATCH `/bookings/:id/cancel`**
```json
{ "reason": "sick" }
```

**POST `/payments`**
```json
{ "booking_id": 99, "provider": "fake", "payment_method_token": "tok_abc" }
```

---

## 14) Events & Subscribers (Observer)

Emit with `ActiveSupport::Notifications.instrument("booking.created", payload)` (or a small custom bus).

**Event names**:
- `booking.created`
- `booking.canceled`
- `booking.reminded`
- `payment.captured`

**Subscribers (skeletons under `app/subscribers/`)**:
```ruby
class SendConfirmationEmail
  def call(event)
    # event[:booking_id] → render via Notifications::EmailRenderer → deliver
    # TODO
  end
end
```

Wire subscribers in an initializer (`config/initializers/subscribers.rb`).

---

## 15) Presenters (ViewModels)

`app/presenters/booking_presenter.rb`
```ruby
class BookingPresenter
  def initialize(booking)
    @booking = booking
  end

  def as_json(*)
    {
      id: @booking.id,
      state: @booking.state,
      price_cents: @booking.price_cents,
      currency: @booking.currency,
      service: { id: @booking.service_id, name: @booking.service.name },
      slot: {
        id: @booking.schedule_slot_id,
        starts_at: @booking.schedule_slot.starts_at,
        ends_at: @booking.schedule_slot.ends_at
      }
    }
  end
end
```

---

## 16) Testing Plan

**Unit (fast, pure Ruby)**
- Value objects: Money/TimeRange/Capacity
- Strategies: pricing, cancellation
- Decorators: WithAddons/WithTax
- Booking states: each transition behavior
- Payments factory: builds correct provider

**Service/Command**
- `BookSlot` happy path & capacity guard
- `CancelBooking` fee calculation and state change
- Events emitted (spy/mocks)

**Request specs**
- `/slots` filters
- `/bookings` create/cancel/reschedule
- `/payments` create

**Factories (FactoryBot)**
- Users (roles), Service, Location, Slot, Booking, AddOn

---

## 17) Step-by-Step Roadmap (Ship Small)

1. **Models + basic validations** (`Service`, `Location`, `ScheduleSlot`, `Booking`, `AddOn`, joins)  
2. **Value Objects** (Money/TimeRange/Capacity)  
3. **/slots#index** + **AvailableSlotsQuery** (without specs → then add specs)  
4. **BookSlot command** (no pricing yet), **BookingsController#create**  
5. **Pricing v1** (`BaseRate`, `PriceCalculator`) + add-ons decorator  
6. **State v1** (`Draft` → `Confirmed`) used during booking creation  
7. **CancelBooking** + **cancellation strategies**  
8. **Payments Factory** + `fake` provider + **PaymentsController#create**  
9. **Presenters** for clean JSON + request specs pass  
10. **Observers**: confirmation email (log output)  
11. **Surge/member pricing** + **reschedule** flow  
12. **Refactor**: extract policies, specs, tighten validations

Ship after step 4; iterate.

---

## 18) Seed Data (Dev Convenience)

`db/seeds.rb` (outline only):
- Create a couple of providers, services, locations.  
- Generate `ScheduleSlot`s for the next 7 days.  
- Add a few add-ons.  
- Create a demo customer.

Run:
```bash
rails db:seed
```

---

## 19) Security & Ops Notes

- **AuthN/Z**: Start with a simple token header; later add Devise + Pundit for policies.
- **Input validation**: Strong params + guards in commands.
- **Idempotency**: Consider an `Idempotency-Key` header for create endpoints.
- **Money**: Always cents (integer); format at edges only.
- **Time zones**: Store UTC, convert on display.
- **Background jobs**: Use ActiveJob (inline in dev) → Sidekiq in prod.
- **Observability**: Log event names, booking IDs, timings.
- **N+1**: Use `includes` in controllers/queries.

---

## 20) Example cURL Flow (Smoke Test)

```bash
# List services
curl -s http://localhost:3000/services

# Find slots
curl -s "http://localhost:3000/slots?service_id=1&date=2025-08-21&location_id=2"

# Book a slot
curl -X POST http://localhost:3000/bookings \
  -H 'Content-Type: application/json' \
  -d '{"customer_id":1,"slot_id":42,"add_on_ids":[3,5]}'

# Cancel a booking
curl -X PATCH http://localhost:3000/bookings/99/cancel \
  -H 'Content-Type: application/json' \
  -d '{"reason":"sick"}'

# Capture payment (fake)
curl -X POST http://localhost:3000/payments \
  -H 'Content-Type: application/json' \
  -d '{"booking_id":99,"provider":"fake","payment_method_token":"tok_demo"}'
```

---

## 21) Stretch Features

- **Waitlist**: auto-promote when slot frees up.
- **Recurring schedules**: weekly slot generator task.
- **Reminders**: email/SMS N hours before slot.
- **Membership tiers**: shared pricing + cancellation strategies.
- **Calendar sync**: Google Calendar adapter.
- **Overbooking rules**: soft capacity buffers.
- **Admin UI**: Hotwire/Turbo or a small React panel.

---

## 22) Glossary

- **PORO**: Plain Old Ruby Object (no Rails deps).
- **Strategy**: Pluggable algorithm behind a stable interface.
- **State**: Object changes behavior based on internal state.
- **Command**: Encapsulated action/use-case.
- **Specification**: Composable query filter.
- **Decorator**: Wrap object to add behavior without changing its class.
- **Adapter/Factory**: Normalize third-party APIs / centralize creation.
- **Observer**: Publish events, decouple side-effects.

---

Happy building! Keep commits small, add tests as you go, and resist the urge to put logic back in models/controllers. This architecture will scale gracefully as you add features.
