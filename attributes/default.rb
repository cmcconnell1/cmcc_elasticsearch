##### cookbook-elasticsearch
# ref: https://github.com/elastic/cookbook-elasticsearch/blob/4.0.0-beta/attributes/default.rb attributes
# empty settings (populate these for the elasticsearch::default recipe)
# see the resources or README.md to see what you can pass here.
default['elasticsearch']['user'] = {}
default['elasticsearch']['install'] = {}
default['elasticsearch']['configure'] = {}
default['elasticsearch']['service'] = {}
default['elasticsearch']['plugin'] = {}

# https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.2.2.rpm
override['elasticsearch']['checksums']['6.2.2']['rhel'] = 'a31277bb89b93da510bf40261882f710a448178ec5430c7a78ac77e91f733cf9'

# chef community elsaticsearch_cookbook hard coded in libraries/resource_install.rb
# attribute(:version, kind_of: String, default: '6.1.1')
# had trouble getting this to work with chef solo changed to '6.2.2' to get past that
#override['elasticsearch']['version'] = '6.2.2' # released February 20, 2018
override['td_elasticsearch']['elasticsearch']['version'] = '6.2.2' # released February 20, 2018
default['td_elasticsearch']['cluster_name'] = 'SOLO'
default['td_elasticsearch']['hostname'] = "#{node['hostname']}"
default['td_elasticsearch']['network_host'] = node['fqdn']
default['td_elasticsearch']['bootstrap_memory_lock'] = true
default['td_elasticsearch']['discovery_zen_hosts_provider'] = 'ec2'
default['td_elasticsearch']['discovery_ec2_groups'] = ['NONE']
default['td_elasticsearch']['discovery_ec2_hosts_type'] = 'private_dns'
default['td_elasticsearch']['discovery_zen_ping_unicast_hosts'] = ['127.0.0.1', '[::1]']
default['td_elasticsearch']['http_port'] = '9200-9300'
default['td_elasticsearch']['transport_host'] = node['fqdn']
default['td_elasticsearch']['transport_tcp_port'] = '9300-9400' 
default['td_elasticsearch']['http_cors_enabled'] = true
default['td_elasticsearch']['http_cors_allow_origin'] = '*'
default['td_elasticsearch']['http_cors_allow_methods'] = 'OPTIONS,HEAD,GET,POST,PUT,DELETE'
default['td_elasticsearch']['http_cors_allow_headers'] = 'X-Requested-With,X-Auth-Token,Content-Type,Content-Length'
default['td_elasticsearch']['discovery_zen_minimum_master_nodes'] = 1
default['td_elasticsearch']['discovery_ec2_tag_env'] = 'NO-ENV'
default['td_elasticsearch']['discovery_ec2_tag_cluster'] = 'NO-CLUSTER'
default['td_elasticsearch']['discovery_ec2_tag_app'] = 'elasticsearch'
default['td_elasticsearch']['xpack_admin_user'] = 'aergo'
default['td_elasticsearch']['xpack_admin_password'] = 'aergo123'
default['td_elasticsearch']['license_file'] = 'terradatum-non-prod'

# we control certs,keys, and ca files based upon the chef env
# the names of the requisite files are the same but in separate encrypted S3 bucket directories
# cluster_name is used to select the requisite S3 bucket location
case ['_default'].include? node.chef_environment
  when true
    override['td_elasticsearch']['cluster_name'] = 'local1'
end

case ['dev'].include? node.chef_environment
  when true
    override['td_elasticsearch']['cluster_name'] = 'dev1'
end

case ['prod'].include? node.chef_environment
  when true
    override['td_elasticsearch']['cluster_name'] = 'prod1'
end

# We set selected requisite certs, keys, and ca files based upon the node name and the domain these each env/cluster has its own requisite files of the same name.
# As noted above the name is the same for all nodes and envs but the chef env controls the source S3 bucket dir.
#case node['fqdn']

case ['elastic1.local','elastic1.dev','elastic1.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic1.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic1.key'
end

case ['elastic2.local','elastic2.dev','elastic2.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic2.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic2.key'
end

case ['elastic3.local','elastic3.dev','elastic3.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic3.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic3.key'
end

case ['elastic4.dev','elastic4.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic4.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic4.key'
end

case ['elastic5.dev','elastic5.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic5.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic5.key'
end

case ['elastic6.dev','elastic6.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic6.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic6.key'
end

case ['elastic7.dev','elastic7.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'elastic7.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'elastic7.key'
end

case ['kibana1.local','kibana1.dev','kibana1.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'kibana1.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'kibana1.key'
end

case ['kibana2.local','kibana2.dev','kibana2.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['xpack_ssl_certificate_file'] = 'kibana2.crt'
    override['td_elasticsearch']['xpack_ssl_key_name']         = 'kibana2.key'
end

override['td_elasticsearch']['xpack_ssl_certificate_path']    = "/etc/elasticsearch/certs/#{node['td_elasticsearch']['xpack_ssl_certificate_file']}"
override['td_elasticsearch']['xpack_ssl_key_path']            = "/etc/elasticsearch/certs/#{node['td_elasticsearch']['xpack_ssl_key_name']}"
override['td_elasticsearch']['xpack_ssl_certificate_auth_file'] = 'ca.crt'
override['td_elasticsearch']['xpack_ssl_certificate_auth_path'] = "/etc/elasticsearch/certs/#{node['td_elasticsearch']['xpack_ssl_certificate_auth_file']}"
# this controls the cluster-specific certs and keys
override['td_elasticsearch']['s3_bucket_remote_path']         = "/certs/elasticsearch/#{node['td_elasticsearch']['cluster_name']}"

##### java
# default jdk attributes
default['java']['jdk_version'] = '8'
default['java']['install_flavor'] = 'oracle'
default['java']['jdk']['7']['x86_64']['url'] = 'http://artifactory.example.com/artifacts/jdk-7u65-linux-x64.tar.gz'
default['java']['jdk']['7']['x86_64']['checksum'] = 'The SHA-256 checksum of the JDK archive'
default['java']['oracle']['accept_oracle_download_terms'] = true

##### kibana
default['td_elasticsearch']['kibana']['version'] = "#{node['td_elasticsearch']['elasticsearch']['version']}"
default['td_elasticsearch']['kibana']['service_user'] = 'kibana'
default['td_elasticsearch']['kibana']['service_group'] = 'kibana'
default['td_elasticsearch']['kibana']['config']['server_port'] = 5601
default['td_elasticsearch']['kibana']['config']['server_host'] = node['fqdn']
override['td_elasticsearch']['kibana']['config_file'] = '/etc/kibana/kibana.yml'
override['td_elasticsearch']['kibana']['config']['logging_dest'] = '/var/log/kibana' # Note: the kibana.rb recipe 'fixes' the kibana RPM's kibana systemd unit file so it logs as it should

override['td_elasticsearch']['kibana']['elasticsearch_username'] = 'kibana'
# use any text string that is 32 characters or longer as the encryption key here we use 64 char rand
override['td_elasticsearch']['kibana']['xpack_security_encryptionkey'] = 'putsomethingreallylongandcleverherexxxxxxx'

override['td_elasticsearch']['kibana']['config']['elasticsearch_url'] = "https://#{node['fqdn']}:9200"
override['td_elasticsearch']['kibana']['network_host'] = node['fqdn']

# elasticsearch.password for kibana.yml
case ['kibana1.local','kibana2.local'].include? node.machinename
  when true
    override['td_elasticsearch']['kibana']['elasticsearch_password'] = '"myinitialelasticsearchpasswordhere"'
end

case ['kibana1.dev','kibana2.dev'].include? node.machinename
  when true
    override['td_elasticsearch']['kibana']['elasticsearch_password'] = '"myinitialkibanapasswordhere"'
end

case ['kibana1.terradatum.com','kibana2.terradatum.com'].include? node.machinename
  when true
    override['td_elasticsearch']['kibana']['elasticsearch_password'] = '"myinitialkibanapasswordhere"'
end

##### cerebro
default['cerebro']['machinename'] = node['machinename']
default['cerebro']['base_dir'] = '/opt'
default['cerebro']['app_name'] = 'cerebro'
# i.e.: https://github.com/lmenezes/cerebro/releases/download/v0.7.2/cerebro-0.7.2.tgz
default['cerebro']['app_version'] = '0.7.2'
default['cerebro']['dist_checksum'] = 'c3f019bd29832550d5ce15d51cf9e4b52c270daca9f35d7602fa06f1ecfa9b4a'
default['cerebro']['dist_archive'] = '.tgz'
default['cerebro']['dist_package'] = "#{node['cerebro']['app_name']}-#{node['cerebro']['app_version']}#{node['cerebro']['dist_archive']}"
default['cerebro']['dist_url'] = "https://github.com/lmenezes/cerebro/releases/download/v#{node['cerebro']['app_version']}/#{node['cerebro']['app_name']}-#{node['cerebro']['app_version']}.tgz"
default['cerebro']['install_dir'] = "#{node['cerebro']['base_dir']}/#{node['cerebro']['app_name']}"
default['cerebro']['config_dir'] = "#{node['cerebro']['base_dir']}/#{node['cerebro']['app_name']}/current/conf"
default['cerebro']['app_bin_path'] = "#{node['cerebro']['base_dir']}/#{node['cerebro']['app_name']}/current/bin/#{node['cerebro']['app_name']}"
default['cerebro']['play_log_level'] ='DEBUG'
default['cerebro']['app_log_level'] ='DEBUG'
default['cerebro']['max_logging_history'] ='10'
default['cerebro']['language'] ='en'
# Secret will be used to sign session cookies, CSRF tokens and for other encryption utilities-create string like this in your wrapper CB--dont use this
default['cerebro']['app_secret_key'] ='"putsomethingsecretandlongherexxxxxxxxz"'

default['cerebro']['truststore_file'] = 'kibana1-cerebro-truststore.jks'
default['cerebro']['truststore_path'] = "#{node['cerebro']['config_dir']}"

default['cerebro']['fqdn_hostname'] = node['fqdn']
default['cerebro']['short_hostname'] = node['hostname']
default['cerebro']['app_port'] = 9000 # can be whatever but but note that 9200 is in use by elasticsearch; this must match proxy settings in httpd/apache
default['cerebro']['app_workdir'] = "#{node['cerebro']['base_dir']}/#{node['cerebro']['app_name']}/current"
default['cerebro']['app_systemd_desc'] = 'Elasticsearch Cerebro'
default['cerebro']['app_user'] = 'apache'
default['cerebro']['app_group'] = 'apache'
default['cerebro']['standard_output'] = 'null'
default['cerebro']['standard_error'] = 'journal'
default['cerebro']['timeout_stop_sec'] = 0
default['cerebro']['kill_signal'] = 'SIGTERM'
default['cerebro']['send_sig_kill'] = 'no'
default['cerebro']['success_exit_status'] = 143

##### snapshots
# DEV
case ['kibana1.dev.terradatum.com'].include? node.machinename
  when true
    default['td_elasticsearch']['snapshots']['es_user'] = 'snapshots'
    default['td_elasticsearch']['snapshots']['es_passwd'] = 'es-snapshots-user-pass-here'
    default['td_elasticsearch']['snapshots']['snapshot_limit'] = 7
    default['td_elasticsearch']['snapshots']['snapshot_minute'] = 1
    default['td_elasticsearch']['snapshots']['snapshot_hour'] = 9 # 9 AM UTC = 2 AM PST; UTC = PST +7 (if spring/summer else 3AM in fall/winter due to DLST?)
    default['td_elasticsearch']['snapshots']['rotate_minute'] = 30
    default['td_elasticsearch']['snapshots']['rotate_hour'] = 9
    default['td_elasticsearch']['snapshots']['snapshot_user'] = 'root'
    default['td_elasticsearch']['snapshots']['snapshot_command'] = '/opt/td-elastic-utilties/create-elastic-snapshots.sh -n dev1 -r dev1 -s snapshot-weekly'
    default['td_elasticsearch']['snapshots']['rotate_command'] = '/opt/td-elastic-utilties/rotate-elastic-snapshots.sh -n dev1 -r dev1'
    default['td_elasticsearch']['snapshots']['snapshot_day'] = '*' # nightly/daily
    default['td_elasticsearch']['snapshots']['es_url'] = 'https://kibana1.dev.terradatum.com:9200'
end

# PROD
case ['kibana1.terradatum.com'].include? node.machinename
  when true
    default['td_elasticsearch']['snapshots']['es_user'] = 'snapshots'
    default['td_elasticsearch']['snapshots']['es_passwd'] = 'es-snapshots-user-pass-here'
    default['td_elasticsearch']['snapshots']['snapshot_limit'] = 15
    default['td_elasticsearch']['snapshots']['snapshot_minute'] = 1
    default['td_elasticsearch']['snapshots']['snapshot_hour'] = 9 # 9 AM UTC = 2 AM PST; UTC = PST +7 (if spring/summer else 3AM in fall/winter due to DLST?)
    default['td_elasticsearch']['snapshots']['rotate_minute'] = 30
    default['td_elasticsearch']['snapshots']['rotate_hour'] = 9
    default['td_elasticsearch']['snapshots']['snapshot_user'] = 'root'
    default['td_elasticsearch']['snapshots']['snapshot_command'] = '/opt/td-elastic-utilties/create-elastic-snapshots.sh -n prod1 -r prod1 -s snapshot-nightly'
    default['td_elasticsearch']['snapshots']['rotate_command'] = '/opt/td-elastic-utilties/rotate-elastic-snapshots.sh -n prod1 -r prod1'
    default['td_elasticsearch']['snapshots']['snapshot_day'] = '*' # nightly/daily
    default['td_elasticsearch']['snapshots']['es_url'] = 'https://kibana1.terradatum.com:9200'
end
