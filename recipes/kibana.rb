#include_recipe 'td_elasticsearch::default'

# set vars
hostname = node['td_elasticsearch']['hostname']
server_name = node['fqdn']
server_host = node['td_elasticsearch']['kibana']['config']['server_host']
server_port = node['td_elasticsearch']['kibana']['config']['server_port']
elasticsearch_url = node['td_elasticsearch']['kibana']['config']['elasticsearch_url']
logging_dest = node['td_elasticsearch']['kibana']['config']['logging_dest']
config_file = node['td_elasticsearch']['kibana']['config_file']
service_user = node['td_elasticsearch']['kibana']['service_user']
service_group = node['td_elasticsearch']['kibana']['service_group']

network_host = node['td_elasticsearch']['kibana']['network_host']
cluster_name = node['td_elasticsearch']['cluster_name']
kibana_version = node['td_elasticsearch']['kibana']['version']
xpack_security_encryptionkey = node['td_elasticsearch']['kibana']['xpack_security_encryptionkey']
transport_host = node['td_elasticsearch']['transport_host']
transport_tcp_port = node['td_elasticsearch']['transport_tcp_port']
kibana_elasticsearch_username = node['td_elasticsearch']['kibana']['elasticsearch_username']
kibana_elasticsearch_password = node['td_elasticsearch']['kibana']['elasticsearch_password']
http_port = node['td_elasticsearch']['http_port']
discovery_zen_ping_unicast_hosts = node['td_elasticsearch']['discovery_zen_ping_unicast_hosts']

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

# https://www.elastic.co/guide/en/kibana/6.2/settings.html
# https://www.elastic.co/guide/en/kibana/6.2/using-kibana-with-security.html
# https://www.elastic.co/guide/en/kibana/current/production.html#load-balancing for prod
# https://www.elastic.co/guide/en/elasticsearch/reference/6.2/modules-node.html#modules-node-xpack
#
# Configure the node as a Coordinating only node
# ref: https://www.elastic.co/guide/en/elasticsearch/reference/6.2/modules-node.html#modules-node-xpack
# To create a dedicated coordinating node when X-Pack is installed, set the following in elasticsearch.yml file:
#   node.master: false
#   node.data: false
#   node.ingest: false
#   search.remote.connect: false
#   node.ml: false
#
# Note: that their LWRP always updates the config file even if there are no changes
elasticsearch_configure 'elasticsearch' do

  logging({:"action" => 'INFO'})

  configuration ({
      # set master, data, and ingest = false for a "search load balancer" (fetching data from nodes, aggregating results, etc.)
      'node.name' => hostname,
      'node.master' => false,
      'node.data' => false,
      'node.ingest' => false,
      'search.remote.connect' => false,
      'node.ml' => false,
      'cluster.name' => cluster_name,
      'http.port' => http_port,
      'transport.host' => transport_host,
      'transport.tcp.port' => transport_tcp_port,
      'network.host' => network_host,
      'discovery.zen.ping.unicast.hosts'     => discovery_zen_ping_unicast_hosts,
      'xpack.ssl.key'                        => xpack_ssl_key_path,
      'xpack.ssl.certificate'                => xpack_ssl_certificate_path,
      'xpack.ssl.certificate_authorities'    => xpack_ssl_certificate_auth_path,
      'xpack.security.transport.ssl.enabled' => true,
      'xpack.security.http.ssl.enabled'      => true
  })
  action :manage
end

# Note: that their LWRP always updates the config file even if there are no changes this is very bad for services esp in prod
# service 'elasticsearch' do
#   subscribes :restart, 'file[/etc/elasticsearch/elasticsearch.yml]', :immediately
# end

replace_line "/etc/hosts" do
  replace "127.0.0.1"
  with    "127.0.0.1       localhost.localdomain localhost #{hostname}"
end

# cert must match hostname for TLS
# replace_line "/etc/hosts" do
#   replace "#{server_name} #{host_name}"
#   with    "FQDN #{host_name}"
# end

append_line "/etc/sysctl.conf" do
  line "vm.swappiness=60"
end

# Kibana
# configure Elasticsearch Kibana Repo
# ref: https://www.elastic.co/guide/en/kibana/current/rpm.html#install-rpm
# https://artifacts.elastic.co/downloads/kibana/kibana-6.2.2-x86_64.rpm
# SHA256 kibana-6.2.2-x86_64.rpm = 602954a88f238446ccd105c8646893fe57febc85fd7fb9cc254be09f31da4e6d
yum_repository 'kibana' do
  description 'Kibana repository for 6.x packages'
  baseurl 'https://artifacts.elastic.co/packages/6.x/yum'
  gpgkey 'https://artifacts.elastic.co/GPG-KEY-elasticsearch'
  gpgcheck true
  action :create
  enabled true
end

package 'kibana' do
  version "#{kibana_version}-1"
  #allow_downgrade true
  action :install
end

# elastics kibana RPM is build with logging disabled in the systemd unit file we hack it here sadly
# ORIG: ExecStart=/usr/share/kibana/bin/kibana "-c /etc/kibana/kibana.yml"
# WANTED: ExecStart=/usr/share/kibana/bin/kibana "-c /etc/kibana/kibana.yml -l /var/log/kibana/kibana.log"
# replace_line "/etc/systemd/system/kibana.service" do
#  replace 'ExecStart=/usr/share/kibana/bin/kibana "-c /etc/kibana/kibana.yml"'
#  with    'ExecStart=/usr/share/kibana/bin/kibana "-c /etc/kibana/kibana.yml -l /var/log/kibana/kibana.log"'
# end

# all this to simply install x-pack chef cant seem to create the home dir
user 'kibana' do
  comment 'kibana user'
  manage_home true
  home '/home/kibana'
  shell '/bin/bash'
  action :create
end

directory '/home/kibana' do
  owner "#{service_user}"
  group "#{service_group}"
  mode '0755'
  action :create
end

# create kibana config dir
directory '/etc/kibana' do
  owner "#{service_user}"
  group "#{service_group}"
  mode '0755'
  action :create
end

# create kibana logs dir
directory "#{logging_dest}" do
  owner "#{service_user}"
  group "#{service_group}"
  mode '0755'
  action :create
end

# if needed we could add kibana user to elasticsearch group
# %w{ kibana }.each do |memberlist|
#   group "elasticsearch" do
#     action :manage
#     members memberlist
#   end
# end

# kibana.yml mods
# ref: https://www.elastic.co/guide/en/kibana/current/production.html#enabling-ssl
# ref: https://www.elastic.co/guide/en/kibana/6.2/using-kibana-with-security.html
# SSL for outgoing requests from the Kibana Server (PEM formatted)
# append_line "#{config_file}" do
#   line "server.name: #{server_name}"
#   notifies :restart, 'service[kibana]', :delayed
# end

append_line "#{config_file}" do
  line "server.host: #{server_host}"
  #notifies :restart, 'service[kibana]', :delayed
end

append_line "#{config_file}" do
  line "server.port: #{server_port}"
  #notifies :restart, 'service[kibana]', :delayed
end

append_line "#{config_file}" do
  line "elasticsearch.url: \"#{elasticsearch_url}\""
  #notifies :restart, 'service[kibana]', :delayed
end

# elastic kibana RPM built to NOT do logging need to hack the systemd unit files
# we mod the systemd kibana unit file above which is really a bad idea tho.
# append_line "#{config_file}" do
#   line "logging.dest: #{logging_dest}"
#   notifies :restart, 'service[kibana]', :delayed
# end

append_line "#{config_file}" do
  line "server.ssl.enabled: true"
end

append_line "#{config_file}" do
  line "server.ssl.key: #{xpack_ssl_key_path}"
end

append_line "#{config_file}" do
  line "server.ssl.certificate: #{xpack_ssl_certificate_path}"
end

# use any text string that is 32 characters or longer as the encryption key
append_line "#{config_file}" do
  line "xpack.security.encryptionKey: #{xpack_security_encryptionkey}"
end

append_line "#{config_file}" do
  line "elasticsearch.ssl.certificateAuthorities: #{xpack_ssl_certificate_auth_path}"
end

# elasticsearch.username for kibana.yml
append_line "#{config_file}" do
  line "elasticsearch.username: #{kibana_elasticsearch_username}"
end

# elasticsearch.password for kibana.yml
append_line "#{config_file}" do
  line "elasticsearch.password: #{kibana_elasticsearch_password}"
end

# we installed from RPM we trust it did what it should but we want to bounce service if config modified
service 'kibana' do
  subscribes :restart, "file[#{config_file}]", :immediately
end

# start here: https://www.elastic.co/guide/en/kibana/current/installing-xpack-kb.html
# ref: http://tickets.opscode.com/browse/CHEF-2288
execute "install kibana-plugin" do
  command "runuser -l #{service_user} -c \'/usr/share/kibana/bin/kibana-plugin install x-pack\'"
  not_if '/usr/share/kibana/bin/kibana-plugin list | grep x-pack'
end

service "kibana" do
  action [ :enable, :start ]
end
