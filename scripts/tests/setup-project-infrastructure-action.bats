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
  run grep "config_repo_dir/.devcontainer/devcontainer.json" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
}

@test "setup-project-infrastructure contains workspace generation commands" {
  run grep "repos codespace" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
  run grep "repos workspace" setup-project-infrastructure/action.yml
  [ "$status" -eq 0 ]
}
