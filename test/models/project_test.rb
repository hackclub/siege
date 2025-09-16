require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = @user.projects.build(
      name: "Test Project",
      description: "A test project",
      repo_url: "https://github.com/testuser/testproject",
      demo_url: "https://demo.example.com",
      hackatime_projects: [ "test-project" ]
    )
  end

  test "can_submit? returns true when preparation_phase flag is enabled" do
    # Mock the Flipper flag to be enabled
    Flipper.stub :enabled?, true do
      assert @project.can_submit?
    end
  end

  test "can_submit? returns true when bypass_10_hour_requirement flag is enabled" do
    # Mock the Flipper flag to be enabled
    Flipper.stub :enabled?, true do
      assert @project.can_submit?
    end
  end

  test "can_submit? returns false when no flags are enabled and requirements not met" do
    # Mock the Flipper flags to be disabled
    Flipper.stub :enabled?, false do
      refute @project.can_submit?
    end
  end

  test "validates supported Git hosting service URLs" do
    supported_urls = [
      "https://github.com/testuser/testproject",
      "https://www.github.com/testuser/testproject",
      "https://gitlab.com/testuser/testproject",
      "https://www.gitlab.com/testuser/testproject",
      "https://bitbucket.org/testuser/testproject",
      "https://www.bitbucket.org/testuser/testproject",
      "https://codeberg.org/testuser/testproject",
      "https://www.codeberg.org/testuser/testproject",
      "https://sourceforge.net/testuser/testproject",
      "https://www.sourceforge.net/testuser/testproject",
      "https://dev.azure.com/testuser/testproject",
      "https://git.hackclub.app/testuser/testproject"
    ]

    supported_urls.each do |url|
      @project.repo_url = url
      assert @project.valid?, "Expected #{url} to be valid"
    end
  end

  test "rejects unsupported Git hosting services" do
    unsupported_urls = [
      "https://example.com/testuser/testproject",
      "https://notasupportedservice.com/testuser/testproject"
    ]

    unsupported_urls.each do |url|
      @project.repo_url = url
      refute @project.valid?, "Expected #{url} to be invalid"
      assert_includes @project.errors[:repo_url], "must be a repository URL from a supported Git hosting service (GitHub, GitLab, Bitbucket, Codeberg, SourceForge, Azure DevOps, or Hack Club Git)"
    end
  end

  test "allows blank repository URL" do
    @project.repo_url = ""
    assert @project.valid?

    @project.repo_url = nil
    assert @project.valid?
  end
end
