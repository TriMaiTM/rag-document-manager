class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_DEFAULT_FROM", "Codexys <no-reply@codexys.me>")
  layout "mailer"
end
