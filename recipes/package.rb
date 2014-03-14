#
# Author:: Benjamin Black (<b@b3k.us>) and Sean Cribbs (<sean@basho.com>) and Seth Thomas (<sthomas@basho.com>)
# Cookbook Name:: riak
# Recipe:: package
#
# Copyright (c) 2013 Basho Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

version_str = "#{node['riak']['package']['version']['major']}.#{node['riak']['package']['version']['minor']}"
base_uri = "#{node['riak']['package']['url']}/#{version_str}/#{version_str}.#{node['riak']['package']['version']['incremental']}/"
base_filename = "riak-#{version_str}.#{node['riak']['package']['version']['incremental']}"
platform_version = node['platform_version'].to_i

case node['platform']
when "fedora", "centos", "redhat"
  node.set['riak']['config']['riak_core']['platform_lib_dir'] = "/usr/lib64/riak".to_erl_string if node['kernel']['machine'] == 'x86_64'
  machines = {"x86_64" => "x86_64", "i386" => "i386", "i686" => "i686"}
  base_uri = "#{base_uri}#{node['platform']}/#{platform_version}/"
  package_file = "#{base_filename}-#{node['riak']['package']['version']['build']}.fc#{platform_version}.#{node['kernel']['machine']}.rpm"
  package_uri = base_uri + package_file
  package_name = package_file.split("[-_]\d+\.").first
when "freebsd"
  base_uri = "#{base_uri}#{node['platform']}/#{platform_version}/"
  package_file = "#{base_filename}-FreeBSD-amd64.tbz"
  package_uri = base_uri + package_file
  package_name = package_file.split(".tbz").first
end

if node['riak']['package']['local_package'] == nil
  package_file = node['riak']['package']['local_package']

  cookbook_file "#{Chef::Config[:file_cache_path]}/#{package_file}" do
    source package_file
    owner "root"
    mode 0644
    not_if(File.exists?("#{Chef::Config[:file_cache_path]}/#{package_file}") && Digest::SHA256.file("#{Chef::Config[:file_cache_path]}/#{package_file}").hexdigest == checksum_val)
  end
else

  package_version = "#{version_str}.#{node['riak']['package']['version']['incremental']}-#{node['riak']['package']['version']['build']}"

  case node['platform']
  when "ubuntu", "debian"
    include_recipe "apt"

    if node['platform'] == "ubuntu" && package_version == "1.3.2-1"
      package_version = package_version.gsub(/-/, "~precise")
    end

    apt_repository "basho" do
      uri "http://apt.basho.com"
      distribution node['lsb']['codename']
      components ["main"]
      key "http://apt.basho.com/gpg/basho.apt.key"
    end

    package "riak" do
      action :install
      version package_version
    end

  when "centos", "redhat"
    include_recipe "yum"

    yum_repository "basho" do
      description "Basho Stable Repo"
      url "http://yum.basho.com/el/#{platform_version}/products/x86_64/"
      gpgkey "http://yum.basho.com/gpg/RPM-GPG-KEY-basho"
      action :add
    end

    if platform_version >= 6
      package_version = "#{package_version}.el#{platform_version}"
    end

    package "riak" do
      action :install
      version package_version
    end

  when "fedora"
    remote_file "#{Chef::Config[:file_cache_path]}/#{package_file}" do
      source package_uri
      owner "root"
      mode 0644
      not_if(File.exists?("#{Chef::Config[:file_cache_path]}/#{package_file}") && Digest::SHA256.file("#{Chef::Config[:file_cache_path]}/#{package_file}").hexdigest == node['riak']['package']['checksum']['local'])
    end

    package package_name do
      source "#{Chef::Config[:file_cache_path]}/#{package_file}"
      action :install
    end

  when "freebsd"
   directory "/usr/local/etc/libmap.d" do
     owner 'root'
     group 'wheel'
     action :create
   end

   template "/usr/local/etc/libmap.d/riak.conf" do
     source "libmap.erb"
     action :create
   end

   template "/usr/local/etc/rc.d/riak" do
     source "rcd.erb"
     mode  0755
     action :create
   end

   package "openssl" do
     source "ftp://ftp.freebsd.org/pub/FreeBSD/ports/amd64/packages-9.2-release/Latest/"
     action :install
   end

   remote_file "#{Chef::Config[:file_cache_path]}/#{package_file}" do
     source package_uri
     owner "root"
     mode 0644
     not_if(File.exists?("#{Chef::Config[:file_cache_path]}/#{package_file}") && Digest::SHA256.file("#{Chef::Config[:file_cache_path]}/#{package_file}").hexdigest == node['riak']['package']['checksum']['local'])
   end

   package package_name do
     source Chef::Config[:file_cache_path]
     action :install
     not_if("pkg_info #{base_filename}")
   end
 end
end
