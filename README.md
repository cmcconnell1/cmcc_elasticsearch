# td_elasticsearch Elasticsearch 

## Requirements
* Pre-existing secure and encrypted (via restricted bucket policy) S3 bucket with your pre-existing .key, .crt. .jks \
(cerbro-truststore) files.
    * i.e.: copy them to a S3 bucket path like: terradatum-chef/certs/elasticsearch/dev1
* This chef cookbook code uses the cluster name ('dev1' or 'prod1') to determine the correct PEM and keystore \
files to fetch from the S3 bucket for the cluster.
    * i.e.:
        * terradatum-chef/certs/elasticsearch/prod1
        * terradatum-chef/certs/elasticsearch/dev1
* The nodes should be launched in EC2 with requisite IAM role/policies (and S3 bucket policy) to facilitate access.
    * See below example Secure, Encrypted S3 bucket policy.
## Platforms
- RHEL and derivatives

## Chef
- Chef >= 12.1

## Usage--inclusion via roles
- Elasticsearch
    - Prod:
        - include elasticsearch-prod role
    - Dev:
        - include elasticsearch-dev role
- Kibana and Cerbro
    - Prod:
        - elasticsearch-prod, kibana-prod, cerebro-prod    
    - Dev:
        - elasticsearch-dev, kibana-dev, cerebro-dev    

## Recipes
- `td_elasticsearch::default`
- `td_elasticsearch::kibana`
- `td_elasticsearch::cerebro`
- `td_elasticsearch::snapshots`

## Cookbook and Recipe Overview; TL;DR
Quick high-level summary:
* Chef Provisioning using TLS/SSL certs, keys, etc., for:

    * Elasticsearch with snapshots
        * Recipe: td_elasticsearch::default
        * Installed and configured in systemd.
        * Supports 6.x+ with x-pack TLS requirements.
            * Tested / validated on 6.2.2-1
        * Distributes and configures with (_pre-existing_) TLS/SSL certs, keys, etc. from requisite encrypted, secure \
        S3 bucket/path.
        
    * Elasticsearch snapshots via cron
        * Recipe: td_elasticsearch::snapshots
            * Manage via snapshots section in the attributes/default.rb (and/or via chef environment, roles, etc.) file.
            
    * Kibana (HTTPS/SSL) "Coordinating Node"
        * Recipe: td_elasticsearch::kibana
            * Installed and configured in systemd.
            * Post chef-client available at https URL--i.e.: https://kibana1.terradatum.com:5601
                * Redirects to kibana login/service; the kibana service terminates the TLS/SSL at the kibana app.
            
    * Cerbro (HTTPS/SSL) on the Kibana node
        * Recipe: td_elasticsearch::cerebro
            * Installed and configured in systemd.
            * Terminates TLS/SSL at the web service on port 443 and redirects to the cerebro play/java app running locally on port 9000
                * Post chef-client available at https URL--i.e.: https://kibana1.terradatum.com
                    * Cerebro Redirect to Login page and use the following:
                        * Node Address: 'kibana.terradatum.com:9200'  (9200 is the elasticsearch port)
                        * Username: use your elasticsearch credentials/account–i.e. 'kibana,' 'cmcc', etc.
                        * Password: requisite password for the above elasticsearch login
                        

## Attributes
- `requisite attributes for all above recipes can be set in attributes or in the requisite environment, etc.`

## Notes, Caveats, Issues
### Elasticsearch
* We were forced to use a beta version/branch the version of which was not valid.
    regarding branch: "4.0.0-beta" both berks and chef-client died trying to handle it.
    ```
    {"error":["Invalid cookbook version '4.0.0-beta'."]}
    ```
    To move forward we took the beta branch and version and uploaded this version to our chef server and set to a valid version number.
For now we used ```4.0.0```

* Please review https://github.com/elastic/cookbook-elasticsearch/blob/4.0.0-beta/README.md
* Elasticsearch did not seem capable of using our _wildcard_ certs (signed from Digi) this was a time consuming frustrating exercise.
    * Highly recommend staying on the supported path of configuring/using self-signed CA certs.
* The ES docs for TLS/SSL post 6.x were not complete and lacking many details when this work was done.
    * Many issues were encountered which required ES support to provide steps as new 6.x+ docs were lacking.  
        * Thanks to their support for assisting.
* Highly recommend using PEM format for certs! 
    * We could not use PKCS#12 as this cert format does NOT work with remote curl commands.
    * On that note, currently Kibana must use PEM AFAIK.
* This may have changed, but at that time we couldn't use passphrase on PEM cert unless we included it in the \
elasticsearch.yml file (docs did not state this).  YMMV.

* kitchen
    * Currently requires using Kitchen Vagrant due to required host name changes, etc.
    * Using kitchen docker has been unstable and unreliable for td_elasticsearch on my mac and therefore was forced \
    to stop using it--vagrant just works for me. In addition we need to take actions based on hostname, \
    which is difficult to do/support with Docker.
    * AWS TLS/SSL configuration, testing and validation really can't be done locally so we do some but not all.
    * AWS EC2 ES cluster node discovery cannot be tested locally.
    
## Pre node/cluster deployment requirements
* Note: (see Elasticsearch, Kibana, and cerbro docs for more details on how to create/configure TLS/SSL certs, etc.)
    * There is quite a lot to understand, configure, and do to support TLS for ES--and is outside scope of this doc.
    
* Update/modify the attributes/default.rb, scripts / templates, and license files, S3 bucket/path, PEM certs/keys, \
keystores, user creds, etc., FOR YOUR ENVIRONMENT.
    
* Encrypted S3 buckets with restricted access to only specified AWS Access keys (used by IAM roles).
    * Prod cluster: terradatum-chef/certs/elasticsearch/prod1    
    * Dev cluster:  terradatum-chef/certs/elasticsearch/dev1    
    * Secure encrypted S3 Bucket Policy _example_ (use at your discretion).
        * The policy below enforces encryption in transit, and only allows specified AWS access keys access.
    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    "arn:aws:s3:::terradatum-chef",
                    "arn:aws:s3:::terradatum-chef/*"
                ],
                "Condition": {
                    "StringNotLike": {
                        "aws:userId": [
                            "MYAWSACCESSKEYGOESHER",
                            "XXOXOXOXOXXXOXXXOXXXX"
                        ]
                    }
                }
            },
            {
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    "arn:aws:s3:::terradatum-chef",
                    "arn:aws:s3:::terradatum-chef/*"
                ],
                "Condition": {
                    "Bool": {
                        "aws:SecureTransport": "false"
                    }
                }
            }
        ]
    }
    ```
    
* Requisite .crt, .key, .jks (cerebro) files for every node in respective ES cluster in requisite S3 bucket.
    * You must create these and copy to requisite S3 bucket and path _before_ using these recipes.
    * i.e. for prod1 cluster:
    ``` 
    aws s3 ls s3://terradatum-chef/certs/elasticsearch/prod1/
        ca.key
        elastic1.crt
        elastic1.key
        elastic2.crt
        elastic2.key
        ...
        elastic7.crt
        elastic7.key
        kibana1.crt
        kibana1.key
        kibana2.crt
        kibana2.key
        kibana1-cerebro-truststore.jks
        prod-instances.yml
    ```
    
    cat prod-instances.yml (follow ES docs for process to create these correctly)
    ```
    instances:
      - name: 'elastic1'
        dns: [ 'elastic1.terradatum.com' ]
      - name: 'elastic2'
        dns: [ 'elastic2.terradatum.com' ]
        ...
      - name: 'elastic7'
        dns: [ 'elastic7.terradatum.com' ]
      - name: 'kibana1'
        dns: [ 'kibana1.terradatum.com' ]
      - name: 'kibana2'
        dns: [ 'kibana2.terradatum.com' ]
      ```

## Launching EC2 ES cluster nodes with knife

### DEV (dev1) ES cluster
##### We use the latest elaticsearch AMI (currently ami-e08e9a80)
The initial DEV cluster node JVMs will be configured with ~15.5G RAM available (Xmx, Xms), using the r4.xlarge
We may scale as needed.

##### deploy dev1 DEV cluster using existing custom AMI with 300 GB EBS volume for elasticsearch data
```
for node in elastic{1..3}.dev; do knife ec2 server create --image ami-e08e9a80 -f r4.xlarge --region us-west-1 --subnet subnet-c3b87cab \
-g "sg-ccf91aa3" -g "sg-0e609d6a" -g "sg-56e3ba33" -g "sg-01c54a64" --ssh-key td-aws-dev --ssh-user deploy \
--identity-file "${HOME}/.ssh/td-aws-dev.pem" --node-name "${node}.terradatum.com" -r "role[elasticsearch-dev]" \
--environment dev --fqdn "${node}.terradatum.com" --tags "ENV=DEV,Name=${node}.terradatum.com,APP=elasticsearch,Cluster=dev1" \
--iam-profile chefAwsRole; done
```
### STAGE cluster not used.

### PROD (prod1) cluster
* PROD cluster node JVMs will have ~30.5G RAM using the r4.2xlarge instance types.
    * Further testing will determine the correct value since literature has this number between 24G and 30.5G

##### Deploy using customized ES AMI providing a separate 300GB EBS data volume.
```
for node in elastic{1..3}; do knife ec2 server create --image ami-e08e9a80 -f r4.2xlarge --region us-west-1 --subnet subnet-c4b87cac \
-g "sg-a27ab3c7" -g "sg-a399f7da" -g "sg-56e3ba33" -g "sg-01c54a64" --ssh-key td-aws-ops --ssh-user deploy --identity-file "${HOME}/.ssh/td-aws-ops.pem" \
--node-name "${node}.terradatum.com" -r "role[elasticsearch-prod]" --environment prod --fqdn "${node}.terradatum.com" \
--tags "ENV=PROD,Name=${node}.terradatum.com,APP=elasticsearch,Cluster=prod1" --server-connect-attribute private_ip_address --iam-profile chefAwsRole; done
```
##### PROD (prod1 cluster) kibana node uses default public CentOS-7 latest image because it does NOT need the 300GB ES data volume.
```
for node in kibana1; do knife ec2 server create --image ami-65e0e305 -f  t2.large --region us-west-1 --subnet \
subnet-c4b87cac -g "sg-a27ab3c7" -g "sg-a399f7da" -g "sg-56e3ba33" -g "sg-01c54a64" --ssh-key td-aws-ops \
--ssh-user centos --identity-file "${HOME}/.ssh/td-aws-ops" --node-name "${node}.terradatum.com" \
-r "role[kibana-prod]" --environment prod --fqdn "${node}.terradatum.com" --tags \
"ENV=PROD,Name=${node}.terradatum.com,APP=elasticsearch,Cluster=prod1" --server-connect-attribute private_ip_address \
--iam-profile chefAwsRole; 
done
```

# Post chef knife bootstrap node creation and successful chef-client run

### Run Setup passwords--NOTE the passwords for the accounts will be the same on all nodes in the cluster
##### Set password for users: elastic, kibana, and logstash_system  accounts
###### OPTION1 use auto password generation
Commands shown for LOCAL, DEV, and PROD:
```
/usr/share/elasticsearch/bin/x-pack/setup-passwords auto -u "https://elastic1.local:9200"
/usr/share/elasticsearch/bin/x-pack/setup-passwords auto -u "https://elastic2.dev:9200"
/usr/share/elasticsearch/bin/x-pack/setup-passwords auto -u "https://elastic3.terradatum.com:9200"
```

##### Set passwords 
###### OPTION2 use interactive password creation (you set at command-line)
Commands shown for LOCAL, DEV, and PROD:
```
/usr/share/elasticsearch/bin/x-pack/setup-passwords interactive -u "https://elastic1.local:9200"
/usr/share/elasticsearch/bin/x-pack/setup-passwords interactive -u "https://elastic2.dev:9200"
/usr/share/elasticsearch/bin/x-pack/setup-passwords interactive -u "https://elastic3.terradatum.com:9200"
```

#### Remember to update LastPass with the new passwords for dev and prod clusters

### Validate secure curl with ca cert works
```
curl --cacert /etc/elasticsearch/certs/ca.crt -u elastic 'https://elastic1.local:9200/_cat/nodes'
curl --cacert /etc/elasticsearch/certs/ca.crt -u elastic 'https://elastic2.dev:9200/_cat/nodes'
curl --cacert /etc/elasticsearch/certs/ca.crt -u elastic 'https://elastic3.terradatum.com:9200/_cat/nodes'

# using elastic account and password with curl
curl --cacert /etc/elasticsearch/certs/ca.crt -u elastic:XXXXXXXX 'https://elastic3.terradatum.com:9200/_cat/nodes'
10.1.0.60  1 57 0 0.00 0.13 0.14 mdi * elastic1
10.1.0.94  1 56 3 0.07 0.20 0.23 mdi - elastic3
10.1.0.196 2 57 0 0.13 0.16 0.20 mdi - elastic2
```

### Export ES_USR, ES_PASSWD (with admin super/admin creds), and CURL_CA_BUNDLE for easier curl commands
Note: not the/a snapshot user, use a real admin/super user. The snapshot user can create snapshots is limited.
i.e.:
```
export CURL_CA_BUNDLE="/etc/elasticsearch/certs/ca.crt"
export ES_USR="my_admin_user"
export ES_PASSWD="my_admin_passwd"
curl -u $ES_USR:$ES_PASSWD -X GET "${ES_URL}/_cat/nodes"
10.1.0.60  7 59 0 0.00 0.01 0.05 mdi * elastic1
10.1.0.103 6 92 2 0.00 0.02 0.05 -   - kibana1
10.1.0.94  6 61 0 0.00 0.01 0.05 mdi - elastic3
10.1.0.196 8 62 0 0.00 0.01 0.05 mdi - elastic2
```

# Elasticsearch Snapshots
* Configured on the target kibana coordinating (or other cluster) node by the td_elasticsearch::snapshots recipe.
* Fully configurable via the snapshots section of the attributes/default.rb file.

## snapshot validation post chef-client run
```
[root@kibana1 ~]# ll /etc/cron.d | grep 'elastic-snapshots'
-rw-r--r--. 1 root root 157 May  9 20:27 prod-create-elastic-snapshots
-rw-r--r--. 1 root root 139 May 10 17:08 prod-rotate-elastic-snapshots

[root@kibana1 ~]# cat /etc/cron.d/prod-create-elastic-snapshots
# Generated by Chef. Changes will be overwritten.
1 9 * * * root /opt/td-elastic-utilties/create-elastic-snapshots.sh -n prod1 -r prod1 -s snapshot-nightly

[root@kibana1 ~]# cat /etc/cron.d/prod-rotate-elastic-snapshots
# Generated by Chef. Changes will be overwritten.
10 17 * * * root /opt/td-elastic-utilties/rotate-elastic-snapshots.sh -n prod1 -r prod1
```

## validate snapshot limits enforced by our scripts from cron
In our case on prod we'll keep 15 snapshots
```
[root@kibana1 ~]# grep LIMIT /opt/td-elastic-utilties/prod1-cluster-vars
# LIMIT must be >= 1
export LIMIT=15

[root@kibana1 ~]# source /opt/td-elastic-utilties/prod1-cluster-vars
[root@kibana1 ~]# env | grep LIMIT
LIMIT=15

[root@kibana1 ~]# curl -u $ES_USR:$ES_PASSWD -X GET "${ES_URL}/_snapshot/prod1/_all?pretty" --silent | jq -r '.snapshots [] .snapshot'
snapshot-bruins-20180508-110550
snapshot-wild-20180508-110600
snapshot-coyotes-20180508-121008
snapshot-ducks-20180508-121022
snapshot-from-kibana-test1-20180508-193648
snapshot-whalers-20180508-125408
snapshot-redwings-20180508-125945
snapshot-sharks-20180508-130241
snapshot-stars-20180508-131301
snapshot-nightly-20180509-161401
snapshot-nightly-20180509-161901
snapshot-nightly-20180509-171901
snapshot-nightly-20180509-181901
snapshot-nightly-20180509-190101
snapshot-nightly-20180510-090101

```

# Licensing nodes/cluster
We have this automated but currently disabled and are just doing this simple step manually, the requisite license file is delivered to /var/tmp
Optionally, you could omit the password and enter it in interactively when you execute the command
```
curl --cacert /etc/elasticsearch/certs/ca.crt -XPUT -u elastic:XXXXXXX 'https://elastic1.terradatum.com:9200/_xpack/license' -H 'Content-Type: application/json' -d @/var/tmp/terradatum-prod.json
{"acknowledged":true,"license_status":"valid"}
```

# Kibana coordinating nodes with requisite TLS/SSL certs, etc.
### deploy kibana dev coordinating node
```
export node=kibana1.dev
knife ec2 server create --image ami-65e0e305 -f t2.medium --region us-west-1 --subnet subnet-c4b87cac -g sg-d334ccb6 \
-g "sg-ccf91aa3" -g "sg-0e609d6a" -g "sg-56e3ba33" -g "sg-01c54a64" --ssh-key td-aws-dev --ssh-user deploy \
--identity-file "${HOME}/.ssh/td-aws-dev.pem" --node-name "${node}.terradatum.com" -r "role[kibana-dev]" \
--environment dev --fqdn "${node}.terradatum.com" --tags \
"ENV=DEV,Name=${node}.terradatum.com,APP=elasticsearch,Cluster=dev1" --iam-profile chefAwsRole; done 
```
### deploy prod kibana coordinating node(s) using default community CentOS AMI
``` 
for node in kibana{1..2}; do 
    knife ec2 server create --image ami-65e0e305 -f  t2.large --region us-west-1 --subnet subnet-c4b87cac \
    -g "sg-a27ab3c7" -g "sg-a399f7da" -g "sg-56e3ba33" -g "sg-01c54a64" --ssh-key td-aws-ops --ssh-user \
    centos --identity-file "${HOME}/.ssh/td-aws-ops" --node-name "${node}.terradatum.com" -r "role[kibana-prod]" \
    --environment prod --fqdn "${node}.terradatum.com" --tags \
    "ENV=PROD,Name=${node}.terradatum.com,APP=elasticsearch,Cluster=prod1" \
    --server-connect-attribute private_ip_address --iam-profile chefAwsRole; 
done
```

## Trust your cluster's CA TLS/SSL Certificate (that you created with the certs and keys) on OSX/MACOS
* If not on OSX/MACOS, use appropriate alternatives here.
    * For OSX/MACOS Go to keychain
        * Trust the ca.crt (available from either LastPass or in /etc/elasticsearch/certs on cluster nodes) in your keychain
            * File - Import
            * Import the ca.crt
            * Open Trust - and under SSL click always trust

## LOCAL development using Chef Kitchen (limited functionality but good for baseline / minimal testing)
```
configure aliases for easy kitchen use
alias elastic1="kitchen login elastic1-centos-7"
alias elastic2="kitchen login elastic2-centos-7"
alias elastic3="kitchen login elastic3-centos-7"
alias kibana1="kitchen login kibana1-centos-7"
```
# deploy two elasticsearch suites (two nodes for testing)
```
kitchen converge 'elastic1|elastic2' -c
```

# deploy two elastic suites/nodes and one kibana
```
kitchen converge 'elastic1|elastic2|kibana1' -c
-----> Starting Kitchen (v1.19.2)
-----> Creating <elastic1-centos-7>...
-----> Creating <elastic2-centos-7>...
-----> Creating <kibana1-centos-7>...
```

```
for i in elastic{1..3}; do kitchen exec $i -c "hostname -I"; done
-----> Execute command on elastic1-centos-7.
       10.0.2.15 172.28.128.6
-----> Execute command on elastic2-centos-7.
       10.0.2.15 172.28.128.7
-----> Execute command on elastic3-centos-7.
       10.0.2.15 172.28.128.8
```

### kitchen.yml file
```
concurrency: 2

driver:
  name: vagrant
  cachier: true
  use_sudo: false
  privileged: true

provisioner:
  name: chef_zero
  log_level: info
  always_update_cookbooks: true

verifier:
  name: inspec
  format: documentation

platforms:
  - name: centos-7

suites:
  - name: elastic1
    driver:
      network:
        - ["private_network", { type: "dhcp" }]
      vm_hostname: elastic1.local
      customize:
        name: elastic1
        memory: 2048
        cpus: 2
    synced_folders:
      - ["/var/tmp/data", "/home/vagrant/data", "create: true, type: :nfs"]
    run_list:
      - recipe[td_elasticsearch::default]

  - name: elastic2
    driver:
      network:
        - ["private_network", { type: "dhcp" }]
      vm_hostname: elastic2.local
      customize:
        name: elastic2
        memory: 2048
        cpus: 2
    synced_folders:
      - ["/var/tmp/data", "/home/vagrant/data", "create: true, type: :nfs"]
    run_list:
      - recipe[td_elasticsearch::default]

  - name: elastic3
    driver:
      network:
        - ["private_network", { type: "dhcp" }]
      vm_hostname: elastic3.local
      customize:
        name: elastic3
        memory: 2048
        cpus: 2
    synced_folders:
      - ["/var/tmp/data", "/home/vagrant/data", "create: true, type: :nfs"]
    run_list:
      - recipe[td_elasticsearch::default]

  - name: kibana1
    driver:
      network:
        - ["private_network", { type: "dhcp" }]
      vm_hostname: kibana1.local
      customize:
        name: kibana1
        memory: 2048
        cpus: 2
    synced_folders:
      - ["/var/tmp/data", "/home/vagrant/data", "create: true, type: :nfs"]
    run_list:
      - recipe[td_elasticsearch::default]
      - recipe[td_elasticsearch::kibana]
```
