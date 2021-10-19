#!/bin/bash

# This script provides a reliable and consistent way to install and manage Ruby
# on your laptop.

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\\n$fmt\\n" "$@"
}

append_to_file() {
  local file="$1"
  local text="$2"

  if ! grep -qs "^$text$" "$file"; then
    printf "\\n%s\\n" "$text" >> "$file"
  fi
}

append_to_beginning_of_file() {
  local file="$1"
  local text="$2"

  if ! grep -qs "^$text$" "$file"; then
    echo "$text" | cat - "$file" > temp && mv temp "$file"
  fi
}

create_zshrc_and_set_it_as_shell_file() {
  if [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.zshrc"
  fi

  shell_file="$HOME/.zshrc"
}

create_bash_profile_and_set_it_as_shell_file() {
  if [ ! -f "$HOME/.bash_profile" ]; then
    touch "$HOME/.bash_profile"
  fi

  shell_file="$HOME/.bash_profile"
}

create_fish_config_and_set_it_as_shell_file() {
  if [ ! -d "$HOME/.config/fish" ]; then
     mkdir "$HOME/.config/fish"
  fi

  if [ ! -f "$HOME/.config/fish/config.fish" ]; then
    touch "$HOME/.config/fish/config.fish"
  fi

  shell_file="$HOME/.config/fish/config.fish"
}

apple_m1() {
  sysctl -n machdep.cpu.brand_string | grep "Apple M1"
}

rosetta() {
  uname -m | grep "x86_64"
}

homebrew_installed_on_m1() {
  apple_m1 && ! rosetta && [ -d "/opt/homebrew" ]
}

homebrew_installed_on_intel() {
  ! apple_m1 && command -v brew >/dev/null
}

install_or_update_homebrew() {
  if homebrew_installed_on_m1 || homebrew_installed_on_intel; then
    update_homebrew
  else
    install_homebrew
  fi
}

install_homebrew() {
  fancy_echo "Installing Homebrew ..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  configure_shell_file_for_homebrew
}

update_homebrew() {
  fancy_echo "Homebrew already installed. Updating Homebrew ..."
  configure_shell_file_for_homebrew
  brew update
}

check_processor_and_set_chruby_source_strings() {
  if apple_m1 && ! rosetta; then
    chruby_source_string="source /opt/homebrew/opt/chruby/share/chruby/chruby.sh"
    auto_source_string="source /opt/homebrew/opt/chruby/share/chruby/auto.sh"
  else
    chruby_source_string="source /usr/local/share/chruby/chruby.sh"
    auto_source_string="source /usr/local/share/chruby/auto.sh"
  fi
}

configure_shell_file_for_homebrew() {
  if apple_m1 && ! rosetta; then
    configure_shell_file_for_homebrew_on_m1
  else
    # shellcheck disable=SC2016
    append_to_file "$shell_file" 'export PATH="/usr/local/bin:$PATH"'
  fi
}

configure_shell_file_for_homebrew_on_m1() {
  if [[ $SHELL == *fish ]]; then
    # shellcheck disable=SC2016
    append_to_beginning_of_file "$shell_file" 'status --is-interactive; and eval (/opt/homebrew/bin/brew shellenv)'
  else
    # shellcheck disable=SC2016
    append_to_file "$HOME/.zprofile" 'eval $(/opt/homebrew/bin/brew shellenv)'
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
}

configure_shell_file_for_chruby() {
  if [[ ! $SHELL == *fish ]]; then
    append_to_file "$shell_file" "$chruby_source_string"
    append_to_file "$shell_file" "$auto_source_string"
  fi

  local ruby_version="$1"
  append_to_file "$shell_file" "chruby ruby-$ruby_version"
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

case "$SHELL" in
  */zsh) :
    create_zshrc_and_set_it_as_shell_file
    ;;
  */bash)
    create_bash_profile_and_set_it_as_shell_file
    ;;
  */fish)
    create_fish_config_and_set_it_as_shell_file
    ;;
esac

brew_is_installed() {
  brew list -1 --formula | grep -Fqx "$1"
}

gem_install_or_update() {
  if gem list "$1" | grep "^$1 ("; then
    fancy_echo "Updating %s ..." "$1"
    gem update "$@"
  else
    fancy_echo "Installing %s ..." "$1"
    gem install "$@"
  fi
}

latest_installed_ruby() {
  find "$HOME/.rubies" -maxdepth 1 -name 'ruby-*' -print0 | sort -z | xargs -0 | grep -E -o '\d+\.\d+\.\d+' | tail -n1
}

ruby_2_7_2_is_installed() {
  find "$HOME/.rubies" -maxdepth 1 -name 'ruby-2.7.3'
}

switch_to_ruby() {
  # shellcheck disable=SC1091
  if apple_m1 && ! rosetta; then
    source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
  else
    source /usr/local/share/chruby/chruby.sh
  fi

  local ruby_version="$1"
  chruby "ruby-$ruby_version"
}

if [[ ! $SHELL == *fish ]]; then
  # shellcheck disable=SC2016
  append_to_file "$shell_file" 'export PATH="$HOME/.bin:$PATH"'
fi

fancy_echo 'Welcome to the Ruby installation script!'
fancy_echo 'You should be and up and running with a working Ruby environment in a few minutes.'
fancy_echo 'The following lines are to help me debug any issues:'
fancy_echo "Current shell: $SHELL"
fancy_echo "Current PATH: $PATH"
# fancy_echo "xcode-select path:"
# xcode-select -p

if command -v rbenv >/dev/null; then
  fancy_echo "rbenv is installed"
fi
if command -v rvm >/dev/null; then
  fancy_echo "rvm is installed"
fi
if command -v asdf >/dev/null; then
  fancy_echo "asdf is installed"
fi

fancy_echo "macOS version:"
sw_vers

fancy_echo "Mac model:"
sysctl hw.model

fancy_echo "Mac CPU:"
sysctl -n machdep.cpu.brand_string

fancy_echo "CPU architecture:"
uname -m

fancy_echo "shell file contents:"
cat $shell_file
fancy_echo "End of shell file contents."

if [ -f "$HOME/.zprofile" ]; then
  fancy_echo ".zprofile contents:"
  cat "$HOME/.zprofile"
  fancy_echo "End of .zprofile contents."
fi

fancy_echo "gem env:"
gem env
fancy_echo "End of gem env."

fancy_echo "End of debugging"

install_or_update_homebrew

fancy_echo "Ruby installed with Homebrew?"
if brew_is_installed "ruby"; then
  echo "yes"
else
  echo "no"
fi

fancy_echo "Verifying the Homebrew installation..."
if brew doctor; then
  fancy_echo "Your Homebrew installation is good to go."
else
  fancy_echo "Your Homebrew installation reported some errors or warnings."
  echo "Review the Homebrew messages to see if any action is needed."
fi

# Avoid downloading the documentation each time you install a gem.
append_to_file "$HOME/.gemrc" 'gem: --no-document'

check_processor_and_set_chruby_source_strings

if command -v rbenv >/dev/null || command -v rvm >/dev/null; then
  fancy_echo 'We recommend chruby and ruby-install over RVM or rbenv.'
  echo "Please uninstall RVM or rbenv, and remove any related lines from $shell_file, then run this script again"
  echo "To uninstall RVM, run 'rvm implode'. To uninstall rbenv, follow the instructions here: https://github.com/rbenv/rbenv#uninstalling-rbenv"
else
  if ! brew_is_installed "chruby"; then
    fancy_echo 'Installing chruby, ruby-install, and the Ruby 2.7.3 ...'

    brew bundle --file=- <<EOF
    brew 'chruby'
    brew 'ruby-install'
    brew 'automake'
    brew 'bison'
    brew 'gdbm'
    brew 'libffi'
    brew 'libyaml'
    brew 'openssl@1.1'
    brew 'readline'
EOF

    ruby-install ruby-2.7.3 -- --with-openssl-dir="$(brew --prefix openssl@1.1)"
    configure_shell_file_for_chruby "2.7.3"
    switch_to_ruby "2.7.3"
  else
    brew bundle --file=- <<EOF
    brew 'git'
    brew 'chruby'
    brew 'ruby-install'
    brew 'automake'
    brew 'bison'
    brew 'gdbm'
    brew 'libffi'
    brew 'libyaml'
    brew 'openssl@1.1'
    brew 'readline'
EOF

    fancy_echo 'Checking if a newer version of Ruby is available...'

    ruby-install --latest > /dev/null
    latest_stable_ruby="$(cat < "$HOME/.cache/ruby-install/ruby/stable.txt" | tail -n1)"

    if ! [ "$latest_stable_ruby" = "$(latest_installed_ruby)" ]; then
      fancy_echo "Installing latest stable Ruby version: $latest_stable_ruby"
      ruby-install ruby -- --with-openssl-dir=$(brew --prefix openssl@1.1)
      configure_shell_file_for_chruby "$(latest_installed_ruby)"
      switch_to_ruby "$(latest_installed_ruby)"
    else
      fancy_echo 'You have the latest version of Ruby'
    fi

    if ! [ "$(ruby_2_7_2_is_installed)" = "$HOME/.rubies/ruby-2.7.3" ]; then
      fancy_echo "Installing Ruby 2.7.3 ..."
      ruby-install ruby-2.7.3 -- --with-openssl-dir="$(brew --prefix openssl@1.1)"
      configure_shell_file_for_chruby "2.7.3"
      switch_to_ruby "2.7.3"
    fi

    configure_shell_file_for_chruby "2.7.3"
  fi
fi

fancy_echo 'Updating Rubygems...'
switch_to_ruby "2.7.3"
gem update --system

fancy_echo 'Installing or updating Bundler'
gem_install_or_update 'bundler'

fancy_echo "Configuring Bundler ..."
number_of_cores=$(sysctl -n hw.ncpu)
bundle config --global jobs $((number_of_cores - 1))

fancy_echo 'All done!'
fancy_echo 'Now make sure to quit and restart your terminal!'
fancy_echo 'If you found this script valuable, join the 2000+ people on my list'
echo "who are becoming confident coders:"
fancy_echo "https://www.moncefbelyamani.com/newsletter"
echo " "
