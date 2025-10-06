PgHero.config["databases"]["primary"] = {
  url: ENV["DATABASE_URL"]
}

# Monitor the queue database used by Solid Queue
PgHero.config["databases"]["queue"] = {
  url: ENV["DATABASE_URL"]
}
