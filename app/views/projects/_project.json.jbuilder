json.cache! [ project, project.cache_key_with_version ] do
  json.extract! project, :id, :name, :repo_url, :demo_url, :created_at, :updated_at
  json.url project_url(project, format: :json)
end
