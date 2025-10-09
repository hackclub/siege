module GithubHelper
  # Extract GitHub repo info from URL
  # Supports: https://github.com/user/repo, https://github.com/user/repo.git
  def extract_github_repo(url)
    return nil unless url.present?
    
    # Match GitHub URLs
    match = url.match(%r{github\.com[/:]([\w-]+)/([\w.-]+?)(?:\.git)?(?:/|$)})
    return nil unless match
    
    {
      owner: match[1],
      repo: match[2].gsub(/\.git$/, '')
    }
  end
  
  # Get the default branch for a repo
  def github_default_branch(owner, repo)
    # Try common default branches
    ['main', 'master'].each do |branch|
      url = "https://github.com/#{owner}/#{repo}/tree/#{branch}"
      begin
        response = HTTP.timeout(5).get(url)
        return branch if response.status.success?
      rescue
        next
      end
    end
    'main' # fallback
  end
end
