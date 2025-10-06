if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
  
  # Detect N+1 queries
  Bullet.n_plus_one_query_enable = true
  
  # Detect eager loading
  Bullet.unused_eager_loading_enable = true
  
  # Detect counter cache
  Bullet.counter_cache_enable = true
end
