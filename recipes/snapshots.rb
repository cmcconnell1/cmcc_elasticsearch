# set vars
es_user          = node['td_elasticsearch']['snapshots']['es_user']
es_passwd        = node['td_elasticsearch']['snapshots']['es_passwd']
es_url           = node['td_elasticsearch']['snapshots']['es_url']
snapshot_limit   = node['td_elasticsearch']['snapshots']['snapshot_limit']
snapshot_minute  = node['td_elasticsearch']['snapshots']['snapshot_minute']
snapshot_hour    = node['td_elasticsearch']['snapshots']['snapshot_hour']
rotate_minute    = node['td_elasticsearch']['snapshots']['rotate_minute']
rotate_hour      = node['td_elasticsearch']['snapshots']['rotate_hour']
snapshot_user    = node['td_elasticsearch']['snapshots']['snapshot_user']
snapshot_command = node['td_elasticsearch']['snapshots']['snapshot_command']
rotate_command   = node['td_elasticsearch']['snapshots']['rotate_command']
snapshot_day     = node['td_elasticsearch']['snapshots']['snapshot_day']

directory '/opt/td-elastic-utilties' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# both prod1 and dev1 clusters use same script
template '/opt/td-elastic-utilties/create-elastic-snapshots.sh' do
  source 'create-elastic-snapshots.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables({})
end

# both prod1 and dev1 clusters use same script
template '/opt/td-elastic-utilties/rotate-elastic-snapshots.sh' do
  source 'rotate-elastic-snapshots.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables({})
end

if node.fqdn == 'kibana1.terradatum.com'
  # config prod1 vars file
  template '/opt/td-elastic-utilties/prod1-cluster-vars' do
    source 'cluster-vars.erb'
    owner 'root'
    group 'root'
    mode '0600'
    variables({
                  :es_user        => es_user,
                  :es_passwd      => es_passwd,
                  :es_url         => es_url,
                  :snapshot_limit => snapshot_limit
              })
  end
  # Configure cron nightly snapshot creation for prod1
  # setting 'minute 14' (using UTC) would create /etc/cron.d/prod-create-elastic-snapshots file:
  # 14 * * * * root /opt/td-elastic-utilties/create-elastic-snapshots.sh -n prod1 -r prod1 -s snapshot-nightly
  # Notes cron_d chef cookbook
  #   Time:
  #     does not accept leading zero (use '1' not '01')
  #     only supports using one minute settings here--i.e. can't use multiple '14,56' etc. else throws errors valid: (0..1)
  #   Default is '*' for all paramaters, so note that if you don't specify hour then it will run every hour.
  # UTC = PST + 7 (or +8 if past Fall DLST start)
  #
  # List snapshots:
  #   env | grep CURL_CA_BUNDLE
  #   CURL_CA_BUNDLE=$HOME/certs/elasticsearch/prod1/ca/ca.crt
  #   curl -u ${ES_USR}:${ES_PASSWD} -s -XGET "https://kibana.terradatum.com:9200/_cat/snapshots/prod1?v&s=id"
  cron_d 'prod-create-elastic-snapshots' do
    minute  snapshot_minute
    hour    snapshot_hour # 2 AM PST (if spring/summer else 3AM in fall/winter AIR?)
    day     snapshot_day # nightly/daily
    command snapshot_command
    user    snapshot_user
  end
  # offset time for the rotation of snapshots
  cron_d 'prod-rotate-elastic-snapshots' do
    minute  rotate_minute
    hour    rotate_hour # 2 AM PST (if spring/summer else 3AM in fall/winter AIR?)
    day     snapshot_day # nightly/daily
    command rotate_command
    user    snapshot_user
  end
end


if node.fqdn == 'kibana1.dev.terradatum.com'
  # config prod1 vars file
  template '/opt/td-elastic-utilties/dev1-cluster-vars' do
    source 'cluster-vars.erb'
    variables({
                  :es_user        => es_user,
                  :es_passwd      => es_passwd,
                  :es_url         => es_url,
                  :snapshot_limit => snapshot_limit
              })
  end
  # weekly cron snapshot for dev1
  # UTC = PST + 7 (or +8 if past Fall DLST start)
  cron_d 'dev-create-elastic-snapshots' do
    minute  snapshot_minute
    hour    snapshot_hour # 2 AM PST (if spring/summer else 3AM in fall/winter AIR?)
    day     snapshot_day # nightly/daily
    command snapshot_command
    user    snapshot_user
  end
  # offset time for the rotation of snapshots
  cron_d 'dev-rotate-elastic-snapshots' do
    minute  rotate_minute
    hour    rotate_hour # 2 AM PST (if spring/summer else 3AM in fall/winter AIR?)
    day     snapshot_day # nightly/daily
    command rotate_command
    user    snapshot_user
  end
end

