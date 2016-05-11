#
# Cookbook Name:: rails-passenger
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

apt_update 'my_update' do
  frequency 86_400
  action :periodic
end

apt_repository 'passenger' do
  uri 'https://oss-binaries.phusionpassenger.com/apt/passenger'
  components ['main']
  keyserver 'keyserver.ubuntu.com'
  key '561F9B9CAC40B2F7'
end
directory '/opt/ruby-on-rails'
directory '/opt/ruby-on-rails/deploy'

remote_file 'ruby_download' do
  source 'http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.4.tar.gz'
  path '/opt/ruby-on-rails/ruby-2.1.4.tar.gz'
  notifies :run, 'execute[ruby_untar]', :immediate
end

execute 'ruby_untar' do
  command 'tar -xvzf /opt/ruby-on-rails/ruby-2.1.4.tar.gz -C /opt/ruby-on-rails'
  action :nothing
  notifies :run, 'execute[ruby_configure]', :immediate
end

execute 'ruby_configure' do
  command './configure && make && make install'
  action :nothing
  cwd '/opt/ruby-on-rails/ruby-2.1.4'
end

%w(apt-transport-https ca-certificates apache2 libsqlite3-dev g++ curl).each \
do |install_package|
  package install_package do
    action :install
  end
end

package 'libapache2-mod-passenger' do
  action :install
  notifies :run, 'execute[mod_passenger_enable]', :delayed
end

gem_package 'rails' do
  action :install
  options '--no-rdoc --no-ri'
end
gem_package 'sqlite3' do
  action :install
end

execute 'rails-create-testapp' do
  cwd '/opt/ruby-on-rails/deploy'
  command 'rails new testapp --skip-bundle'
  creates '/opt/ruby-on-rails/deploy/testapp'
end

execute 'mod_passenger_enable' do
  action :nothing
  command 'a2enmod passenger'
  notifies :restart, 'service[apache2]', :immediate
end

link '/usr/bin/ruby' do
  to '/usr/local/bin/ruby'
end

service 'apache2' do
  action [:enable, :start]
end

template 'testapp-Gemfile' do
  source 'testapp-Gemfile.erb'
  action :create
  path '/opt/ruby-on-rails/deploy/testapp/Gemfile'
  notifies :run, 'execute[testapp-bundle-install]', :immediate
end

execute 'testapp-bundle-install' do
  command 'bundle install'
  cwd '/opt/ruby-on-rails/deploy/testapp'
  action :nothing
end

template 'testapp-apache-site.conf' do
  source 'testapp-apache-site.conf.erb'
  path '/etc/apache2/sites-available/testapp.conf'
  notifies :restart, 'service[apache2]', :delayed
end

execute 'a2dissite 000-default' do
  only_if {File.exist?('/etc/apache2/sites-enabled/000-default.conf')}
  notifies :restart, 'service[apache2]', :delayed
end

execute 'a2ensite testapp' do
  not_if {File.exist?('/etc/apache2/sites-enabled/testapp.conf')}
  notifies :restart, 'service[apache2]', :delayed
end
