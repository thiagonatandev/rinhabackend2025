require "sidekiq/api"

Rails.application.routes.draw do
  resources :payments, only: [ :create ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "/payments-summary", to: "payments#summary"

  # Defines the root path route ("/")
  # root "posts#index"
  get "/sidekiq/health", to: ->(env) {
    stats = Sidekiq::Stats.new
    [ 200, { "Content-Type" => "application/json" }, [ {
      processed: stats.processed,
      failed: stats.failed,
      enqueued: stats.enqueued,
      retry_size: stats.retry_size,
      processes: stats.processes_size,
      default_latency: stats.default_queue_latency
    }.to_json ] ]
  }

  get "/sidekiq/stats", to: ->(env) {
    stats = Sidekiq::Stats.new
    queues = Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size, latency: q.latency } }

    [ 200, { "Content-Type" => "application/json" }, [ {
      queues: queues,
      processed: stats.processed,
      failed: stats.failed,
      busy: stats.workers_size
    }.to_json ] ]
  }
end
