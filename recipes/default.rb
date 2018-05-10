#
# Cookbook:: td_elasticsearch
# Recipe:: default
# Copyright:: 2018, The Authors, All Rights Reserved.

# TD_ELASTICSEARCH WRAPPER VARIABLE DECLARATIONS
td_elasticsearch_version                    = node['td_elasticsearch']['elasticsearch']['version']
td_elasticsearch_version_checksum           = node['elasticsearch']['checksums']['6.2.2']['rhel']
hostname                                    = node['td_elasticsearch']['hostname']
cluster_name                                = node['td_elasticsearch']['cluster_name']
network_host                                = node['td_elasticsearch']['network_host']
bootstrap_memory_lock                       = node['td_elasticsearch']['bootstrap_memory_lock']
discovery_zen_hosts_provider                = node['td_elasticsearch']['discovery_zen_hosts_provider']
discovery_ec2_groups                        = node['td_elasticsearch']['discovery_ec2_groups']
discovery_ec2_host_type                     = node['td_elasticsearch']['discovery_ec2_host_type']
discovery_zen_ping_unicast_hosts            = node['td_elasticsearch']['discovery_zen_ping_unicast_hosts']
discovery_zen_minimum_master_nodes          = node['td_elasticsearch']['discovery_zen_minimum_master_nodes']
http_port                                   = node['td_elasticsearch']['http_port']
transport_tcp_port                          = node['td_elasticsearch']['transport_tcp_port']
http_cors_enabled                           = node['td_elasticsearch']['http_cors_enabled']
http_cors_allow_origin                      = node['td_elasticsearch']['http_cors_allow_origin']
http_cors_allow_methods                     = node['td_elasticsearch']['http_cors_allow_methods']
http_cors_allow_headers                     = node['td_elasticsearch']['http_cors_allow_headers']
discovery_ec2_tag_env                       = node['td_elasticsearch']['discovery_ec2_tag_env']
discovery_ec2_tag_cluster                   = node['td_elasticsearch']['discovery_ec2_tag_cluster']
discovery_ec2_tag_app                       = node['td_elasticsearch']['discovery_ec2_tag_app']
xpack_admin_user                            = node['td_elasticsearch']['xpack_admin_user']
xpack_admin_password                        = node['td_elasticsearch']['xpack_admin_password']
license_file                                = node['td_elasticsearch']['license_file']

# PEM certs
xpack_ssl_certificate_file        = node['td_elasticsearch']['xpack_ssl_certificate_file']
xpack_ssl_certificate_path        = node['td_elasticsearch']['xpack_ssl_certificate_path']
xpack_ssl_certificate_auth_file   = node['td_elasticsearch']['xpack_ssl_certificate_auth_file']
xpack_ssl_certificate_auth_path   = node['td_elasticsearch']['xpack_ssl_certificate_auth_path']
xpack_ssl_key_name                = node['td_elasticsearch']['xpack_ssl_key_name']
xpack_ssl_key_path                = node['td_elasticsearch']['xpack_ssl_key_path']
s3_bucket_remote_path             = node['td_elasticsearch']['s3_bucket_remote_path']

Chef::Log.info("DEBUG xpack_ssl_certificate_file: #{xpack_ssl_certificate_file}")
Chef::Log.info("DEBUG xpack_ssl_certificate_path: #{xpack_ssl_certificate_path}")
Chef::Log.info("DEBUG xpack_ssl_certificate_auth_file: #{xpack_ssl_certificate_auth_file}")
Chef::Log.info("DEBUG xpack_ssl_certificate_auth_path: #{xpack_ssl_certificate_auth_path}")
Chef::Log.info("DEBUG xpack_ssl_key_name: #{xpack_ssl_key_name}")
Chef::Log.info("DEBUG xpack_ssl_key_path: #{xpack_ssl_key_path}")
Chef::Log.info("DEBUG s3_bucket_remote_path: #{s3_bucket_remote_path}")

# databag 'sigh' needed for at least kitchen this is just RO chef user
aws = data_bag_item('aws', 'main')
aws_access_key        = aws['aws_access_key_id']
aws_secret_access_key = aws['aws_secret_access_key']
Chef::Log.info("for non-EC2 instances we will use RO chef users aws_access_key: #{aws_access_key} and its aws_secret_access_key")

## OS SYSTEM MODIFICATIONS
# SYSCTL
# needed to vm.swappiness: 1
# ref: https://www.elastic.co/guide/en/elasticsearch/reference/6.1/setup-configuration-memory.html#swappiness
# ref: https://stackoverflow.com/questions/28866895/chef-unable-to-set-vmswappiness-in-cookbook
node.override['sysctl']['params']['vm']['swappiness'] = '1'

# PATCH
#include_recipe 'patch' # there are no recipes in this LWRP
append_line "/etc/security/limits.conf" do
  line "elasticsearch soft memlock unlimited"
  notifies :restart, 'service[elasticsearch]', :delayed
  not_if "grep 'elasticsearch soft memlock unlimited' /etc/security/limits.conf"
end

append_line "/etc/security/limits.conf" do
  line "elasticsearch hard memlock unlimited"
  notifies :restart, 'service[elasticsearch]', :delayed
  not_if "grep 'elasticsearch hard memlock unlimited' /etc/security/limits.conf"
end

# https://www.elastic.co/guide/en/elasticsearch/reference/6.1/_max_file_size_check.html
# fsize setting to unlimited (note that you might have to increase the limits for the root user too).
# ref: https://access.redhat.com/solutions/61334
append_line "/etc/security/limits.conf" do
  line "elasticsearch - fsize unlimited"
  notifies :restart, 'service[elasticsearch]', :delayed
  not_if "grep 'elasticsearch - fsize unlimited' /etc/security/limits.conf"
end

append_line "/etc/security/limits.conf" do
  line "root - fsize unlimited"
  notifies :restart, 'service[elasticsearch]', :delayed
  not_if "grep 'root - fsize unlimited' /etc/security/limits.conf"
end

# PACKAGES
package %w(vim tree)

execute 'bash_completion' do
  command 'yum install -y bash-completion bash-completion-extras'
  not_if 'yum list installed | grep bash-completion'
end

# JAVA
include_recipe 'java::default'

# ELASTICSEARCH
include_recipe 'elasticsearch::default'

# 'Installed package elasticsearch-6.2.2-1 is newer than candidate package elasticsearch-6.1.1-1' the lower ver seems to come from elasticsearch cookbook
# elasticsearch_install 'elastic_install' do
#   type 'package'
#   version td_elasticsearch_version
#   action :install # currently only supports install
# end
elasticsearch_install 'elastic_install' do
  type 'package'
  download_url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-#{td_elasticsearch_version}.rpm"
  # sha256
  download_checksum td_elasticsearch_version_checksum
  action :install # currently only supports install
end

service 'elasticsearch' do
  action [ :enable, :start ]
end

# ref: https://www.elastic.co/guide/en/elasticsearch/reference/6.1/setting-system-settings.html#systemd
# /etc/systemd/system/elasticsearch.service.d/override.conf
# [Service]
# LimitMEMLOCK=infinity
insert_line_after "/usr/lib/systemd/system/elasticsearch.service" do
  line "[Service]"
  insert "LimitMEMLOCK=infinity"
  notifies :restart, "service[elasticsearch]", :delayed
  notifies :run, 'execute[systemctl daemon-reload]'
  not_if "grep 'LimitMEMLOCK=infinity' /usr/lib/systemd/system/elasticsearch.service"
end

# now must execute systemctl daemon-reload
execute "systemctl daemon-reload" do
  user "root"
  action :nothing
end

# no plugins initially, but we must add the x-pack for TLS and licensing, etc.
elasticsearch_plugin 'x-pack' do
  not_if "/usr/share/elasticsearch/bin/elasticsearch-plugin list | grep x-pack"
  notifies :restart, 'elasticsearch_service[elasticsearch]', :delayed
end

elasticsearch_plugin 'discovery-ec2' do
  not_if "/usr/share/elasticsearch/bin/elasticsearch-plugin list | grep x-discovery"
  notifies :restart, 'elasticsearch_service[elasticsearch]', :delayed
end

elasticsearch_plugin 'repository-s3' do
  not_if "/usr/share/elasticsearch/bin/elasticsearch-plugin list | grep repository-s3"
  notifies :restart, 'elasticsearch_service[elasticsearch]', :delayed
end

# Create the X-Pack admin user
execute 'create aergo elasticsearch user' do
  not_if "/usr/share/elasticsearch/bin/x-pack/users list | grep '#{xpack_admin_user}'"
  command "/usr/share/elasticsearch/bin/x-pack/users useradd '#{xpack_admin_user}' -p '#{xpack_admin_password}' -r superuser"
  notifies :restart, 'elasticsearch_service[elasticsearch]', :delayed
end

execute 'create empty initial elasticsearch-keystore' do
  not_if { ::File.exist?("/etc/elasticsearch/elasticsearch.keystore") }
  user 'elasticsearch'
  command '/usr/share/elasticsearch/bin/elasticsearch-keystore create --silent'
  user 'elasticsearch'
  group 'elasticsearch'
  notifies :restart, 'service[elasticsearch]', :delayed
end

file '/etc/elasticsearch/elasticsearch.keystore' do
  owner 'root'
  group 'elasticsearch'
end

directory '/etc/elasticsearch/certs' do
  owner 'elasticsearch'
  group 'elasticsearch'
  mode '0770'
  action :create
end

directory '/etc/elasticsearch' do
  owner 'root'
  group 'elasticsearch'
  mode '0770'
  action :create
end

# get node.crt
update_ssl_cert_file = aws_s3_file "#{xpack_ssl_certificate_path}" do
  # checksum wont work because this is a different file for each node
  aws_access_key "#{aws_access_key}"
  aws_secret_access_key "#{aws_secret_access_key}"
  bucket 'terradatum-chef'
  region 'us-west-1'
  action :create_if_missing
  remote_path "#{s3_bucket_remote_path}/#{xpack_ssl_certificate_file}"
  owner 'elasticsearch'
  group 'elasticsearch'
end

# NOTE: that due to safety and service outages, etc., the community cookbook for elasticsearch specifically states they dont restart services except for the first initial install.
service 'elasticsearch' do
  subscribes :restart, 'file["#{xpack_ssl_certificate_path}"]', :delayed # this isnt working as expected
  only_if { update_ssl_cert_file.updated_by_last_action? }
end

# get node.key
update_ssl_key_file = aws_s3_file "#{xpack_ssl_key_path}" do
  # checksum wont work because this is a different file for each node
  aws_access_key "#{aws_access_key}"
  aws_secret_access_key "#{aws_secret_access_key}"
  bucket 'terradatum-chef'
  region 'us-west-1'
  action :create_if_missing
  remote_path "#{s3_bucket_remote_path}/#{xpack_ssl_key_name}"
  owner 'elasticsearch'
  group 'elasticsearch'
end

service 'elasticsearch' do
  subscribes :restart, 'file["#{xpack_ssl_key_path}"]', :delayed # this isnt working as expected
  only_if { update_ssl_key_file.updated_by_last_action? }
end

# get requisite ca.crt
update_ssl_cert_auth_file = aws_s3_file "#{xpack_ssl_certificate_auth_path}" do
  aws_access_key "#{aws_access_key}"
  aws_secret_access_key "#{aws_secret_access_key}"
  bucket 'terradatum-chef'
  region 'us-west-1'
  action :create_if_missing
  remote_path "#{s3_bucket_remote_path}/#{xpack_ssl_certificate_auth_file}"
  owner 'elasticsearch'
  group 'elasticsearch'
end

service 'elasticsearch' do
  subscribes :restart, 'file["#{xpack_ssl_certificate_auth_path}"]', :delayed
  only_if { update_ssl_cert_auth_file.updated_by_last_action? }
end

cookbook_file "/var/tmp/#{license_file}.json" do
  source  "#{license_file}.json"
  owner 'elasticsearch'
  group 'elasticsearch'
  mode '0755'
  action :create_if_missing
end

# execute 'install license file' do
#   only_if { ::File.exist?("/var/tmp/#{license_file}.json") }
#   # curl -XGET -u user:passwd 'http://127.0.0.1:9200/_xpack/license' # validate license
#   not_if "curl -XGET -u #{xpack_admin_user}:#{xpack_admin_password} 'http://127.0.0.1:9200/_xpack/license' | grep 'platinum'"
#   # curl -XPUT -u user:passwd 'http://127.0.0.1:9200/_xpack/license' -H "Content-Type: application/json" -d @/var/tmp/terradatum-non-prod.json # install license
#   command  "curl -XPUT -u #{xpack_admin_user}:#{xpack_admin_password} 'http://127.0.0.1:9200/_xpack/license' -H 'Content-Type: application/json' -d @/var/tmp/terradatum-non-prod.json"
#   notifies :restart, 'elasticsearch_service[elasticsearch]', :delayed
# end

# allow for customizing our clusters
#update_es_config = elasticsearch_configure 'elasticsearch' do
# For some reason the community chef cookbook is updating the file every chef run even if there are no changes sad panda
elasticsearch_configure 'elasticsearch' do

  logging({:"action" => 'INFO'})

  configuration ({
      'node.name'                                   => hostname,
      'cluster.name'                                => cluster_name,
      'network.host'                                => network_host,
      'bootstrap.memory_lock'                       => bootstrap_memory_lock,
      'discovery.zen.hosts_provider'                => discovery_zen_hosts_provider,
      'discovery.ec2.groups'                        => discovery_ec2_groups,
      'discovery.ec2.host_type'                     => discovery_ec2_host_type,
      'discovery.zen.ping.unicast.hosts'            => discovery_zen_ping_unicast_hosts,
      'discovery.zen.minimum_master_nodes'          => discovery_zen_minimum_master_nodes,
      'http.port'                                   => http_port,
      'transport.tcp.port'                          => transport_tcp_port,
      'http.cors.enabled'                           => http_cors_enabled,
      'http.cors.allow-origin'                      => http_cors_allow_origin,
      'http.cors.allow-methods'                     => http_cors_allow_methods,
      'http.cors.allow-headers'                     => http_cors_allow_headers,
      'discovery.ec2.tag.env'                       => discovery_ec2_tag_env,
      'discovery.ec2.tag.cluster'                   => discovery_ec2_tag_cluster,
      'discovery.ec2.tag.app'                       => discovery_ec2_tag_app,
      'xpack.ssl.key'                                  => xpack_ssl_key_path,
      'xpack.ssl.certificate'                          => xpack_ssl_certificate_path,
      'xpack.ssl.certificate_authorities'              => xpack_ssl_certificate_auth_path,
      'xpack.security.transport.ssl.enabled'            => true,
      'xpack.security.http.ssl.enabled'                 => true
  })

  action :manage

end

# service 'elasticsearch' do
#   only_if { update_es_config.updated_by_last_action? }
#   action :restart
# end

# file "/var/tmp/#{license_file}.json" do
#   action :delete
# end
