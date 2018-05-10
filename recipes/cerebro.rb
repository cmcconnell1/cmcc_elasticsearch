# Cookbook Name:: cerebro
include_recipe 'java::default' # Note this must exist for elasticsearch

# set vars
install_dir = node['cerebro']['install_dir']
fqdn_hostname = node['cerebro']['fqdn_hostname']
short_hostname = node['cerebro']['short_hostname']
machinename = node['cerebro']['machinename']
app_port = node['cerebro']['app_port']
app_name = node['cerebro']['app_name']
app_user = node['cerebro']['app_user']
app_group = node['cerebro']['app_group']
app_bin_path = node['cerebro']['app_bin_path']
app_workdir = node['cerebro']['app_workdir']
dist_url = node['cerebro']['dist_url']
dist_package = node['cerebro']['dist_package']
dist_checksum = node['cerebro']['dist_checksum']
app_version = node['cerebro']['app_version']
config_dir = node['cerebro']['config_dir']
app_systemd_desc = node['cerebro']['app_systemd_desc']
standard_output = node['cerebro']['standard_output']
standard_error = node['cerebro']['standard_error']
timeout_stop_sec = node['cerebro']['timeout_stop_sec']
kill_signal = node['cerebro']['kill_signal']
send_sig_kill  = node['cerebro']['send_sig_kill']
success_exit_status = node['cerebro']['success_exit_status']
app_secret_key = node['cerebro']['app_secret_key']

truststore_file = node['cerebro']['truststore_file']
truststore_path = node['cerebro']['truststore_path']
s3_bucket_remote_path = node['td_elasticsearch']['s3_bucket_remote_path']

# databag 'sigh' needed for kitchen and non chef provisioned (with role, etc.) this is just RO chef user
aws = data_bag_item('aws', 'main')
aws_access_key        = aws['aws_access_key_id']
aws_secret_access_key = aws['aws_secret_access_key']
Chef::Log.info("for non-EC2 instances we will use RO chef users aws_access_key: #{aws_access_key} and its aws_secret_access_key")

Chef::Log.info("DEBUG fqdn_hostname: #{fqdn_hostname}")

package %w(httpd mod_ssl)

template '/etc/httpd/conf.d/cerebro-service.conf' do
  source 'cerebro.httpd.conf.erb'
  notifies :restart, 'service[httpd]', :delayed
  variables({
                :fqdn_hostname => fqdn_hostname,
                :short_hostname => short_hostname,
                :machinename => machinename,
                :app_port => app_port,
            })
end

# shouldnt need this using RPM install JIC for reference JIC
# template '/etc/httpd/conf.modules.d/00-proxy.conf' do
#   source '00-proxy.conf.erb'
#   notifies :restart, 'service[httpd]', :delayed
# end

service 'httpd' do
  action [ :enable, :start ]
  subscribes :reload, 'template[/etc/httpd/conf.d/cerebro-service.conf]', :immediately
  #subscribes :reload, 'template[/etc/httpd/conf.modules.d/00-proxy.conf]', :immediately
  reload_command 'systemctl daemon-reload'
end

# fetch cerebro app dist
# i.e.: https://github.com/lmenezes/cerebro/releases/download/v0.7.2/cerebro-0.7.2.tgz
remote_file "/var/tmp/#{dist_package}" do
  source dist_url
  checksum dist_checksum
  mode "0755"
  action :create
end

directory install_dir do
  owner app_user
  group app_group
  mode '0755'
  action :create
end

execute 'extract tar.gz file' do
  command "tar xzvf /var/tmp/#{dist_package}"
  cwd install_dir
  not_if { File.exists?("#{config_dir}/application.conf") }
end

# chef why write these backwards?
# linux command ln $target $source
# ln -s cerebro-0.7.2 current
link "#{install_dir}/current" do
  to "#{install_dir}/#{app_name}-#{app_version}"
end

# find /opt/cerebro -type d
# /opt/cerebro
# /opt/cerebro/cerebro-0.7.2
# /opt/cerebro/cerebro-0.7.2/bin
# /opt/cerebro/cerebro-0.7.2/conf
# /opt/cerebro/cerebro-0.7.2/conf/evolutions
# /opt/cerebro/cerebro-0.7.2/conf/evolutions/default
# /opt/cerebro/cerebro-0.7.2/lib
# /opt/cerebro/cerebro-0.7.2/logs
# works but not recursively
# ref: https://github.com/chef/chef/issues/4468
#
# directory "#{install_dir}" do
#   #%w[ /foo /foo/bar /foo/bar/baz ].each do |path| # hmm lots here
#   #%w[  ].each do |path| # icky
#   command lazy {
#     "#{dir_list}".each do |path|
#       owner "#{app_user}"
#       group "#{app_group}"
#       recursive true
#     end
#   }
# end
#
# sadly this is not idempotent the alternative is having to list every sub dir in the tree as noted above
# punting and sadly can live with this for now.
execute "chown-data-#{install_dir}" do
  command "chown -R #{app_user}:#{app_group} #{install_dir}"
  action :run
  only_if "find #{install_dir} \! -user #{app_user}"
end

aws_s3_file "#{truststore_path}/#{truststore_file}" do
  aws_access_key "#{aws_access_key}"
  aws_secret_access_key "#{aws_secret_access_key}"
  bucket 'terradatum-chef'
  region 'us-west-1'
  action :create
  remote_path "#{s3_bucket_remote_path}/#{truststore_file}"
  owner "#{app_user}"
  group "#{app_group}"
end

# Configure Systemd for cerebro
template "/etc/systemd/system/#{app_name}.service" do
  source 'cerebro.service.erb'
  #notifies :restart, "systemd_unit[#{app_name}.service]", :delayed
  notifies :restart, "service[#{app_name}]", :delayed
  variables({
                :app_systemd_desc     => app_systemd_desc,
                :fqdn_hostname        => fqdn_hostname,
                :app_port             => app_port,
                :app_workdir          => app_workdir,
                :app_user             => app_user,
                :app_group            => app_group,
                :app_bin_path         => app_bin_path,
                :standard_output      => standard_output,
                :standard_error       => standard_error,
                :timeout_stop_sec     => timeout_stop_sec,
                :kill_signal          => kill_signal,
                :send_sig_kill        => send_sig_kill,
                :success_exit_status  => success_exit_status
  })
end

# if we need to we can mod app logging here
# template "#{config_dir}/logger.xml" do
#   source "logger.xml.erb"
#   variables({
#             })
# end

# Create the application.conf file
template "#{config_dir}/application.conf" do
  source 'cerebro.application.conf.erb'
  owner "#{app_user}"
  group "#{app_group}"
  mode '0744'
  #notifies :restart, "systemd_unit[#{app_name}.service]", :delayed
  notifies :restart, "service[#{app_name}]", :immediately
  variables({
                :app_secret_key => app_secret_key
            })
end

# as apache user req for term TLS/SSL and proxying for the play app--i.e., for cerebro we are sporting:
# java -Duser.dir=/opt/cerebro/cerebro-0.7.2 -Dhttp.port=9000 -Dhttp.address=kibana1.terradatum.com -cp  -jar /opt/cerebro/cerebro-0.7.2/lib/cerebro.cerebro-0.7.2-launcher.jar
service "#{app_name}" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
  #subscribes :restart, "#{config_dir}/application.conf", :immediately
  reload_command 'systemctl daemon-reload'
end
