#!/usr/bin/env bats

@test "setup-project-infrastructure action exists and is a composite action" {
  run cat setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ "Setup Project Infrastructure" ]]
  [[ "$output" =~ "using: \"composite\"" ]]
}

@test "setup-project-infrastructure inputs include working_repo and template_repo" {
  run grep "working_repo:" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep "template_repo:" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep "builder_repo:" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
}

@test "setup-project-infrastructure parses owner/repo@branch syntax" {
  run grep "parse_repo_string()" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
}

@test "setup-project-infrastructure injects builder workflow and devcontainer.json correctly" {
  run grep "Injecting devcontainer-build.yml workflow" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep "$CONFIG_DIR/.devcontainer/devcontainer.json" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
}

@test "setup-project-infrastructure contains workspace generation commands" {
  run grep "repos codespace" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep "repos workspace" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
}

@test "setup-project-infrastructure uses temporary askpass authentication" {
  run grep -F 'scripts/git-auth-askpass.sh' setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run awk '
    /trap cleanup_git_askpass EXIT/ { trap_line=NR }
    /setup_git_askpass/ { setup_line=NR }
    END { exit (trap_line && setup_line && trap_line < setup_line) ? 0 : 1 }
  ' setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep -F '${GITHUB_SERVER_URL}/${repo_str}.git' setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep -F 'git config --global url.' setup-project-infrastructure/action.yml
  [ "$status" -ne 0 ]
}
