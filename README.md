# SYNOPSIS

`updatewatch` is a collection of ruby and bash scripts to parse (and filter) some sort of release notification input data (such as [endoflife.date](https://endoflife.date/) [data](https://github.com/endoflife-date/release-data) or GitHub release feeds) and create todos for them in your favorite ticket/task management system. The goal is to build a bridge between the software releases popped out there in the world and your sysadmin-team's task organization workflow.

# REQUIREMENTS

- ruby 2.7+
- bash 5.0+
- git
- curl
- ticketing system:
  - Atlassian Jira
  - JetBrains YouTrack

# SETUP

- log in to your Jira/YouTrack/... account, navigate to your profile or project settings and create a personal access token (PAT) / project token / bearer token / ...  
  if necessary, make sure your token has the required permissions to create/modify/update tickets in the project you're using
- create a file called `settings` in this directory (where the `defaults` file is located too); insert the token there by assigning the value to a shell variable called `TOKEN`  
  note: changes to the `defaults` file are recognized by the git environment (which might be intended for your static and non-secret data); `settings` is ignored by git
- optionally adjust other variables to fit your needs  
  a sample `settings` file might look like this:
  ```bash
  TOKEN=1234567890abcdefghijklmnopqrstuvwxyz1234567890
  THOST=https://tickets.company.org
  API=/rest/api/2/issue
  APIBULK=/rest/api/2/issue/bulk
  ```
  or like this:
  ```bash
  TOKEN=1234567890abcdefghijklmnopqrstuvwxyz1234567890
  THOST=https://tickets.company.org
  API=/api/issues?fields=id,idReadable,summary
  
  TEMPLATE=youtrack
  # optional request arguments that will get passed to generate_changerequest.rb by update.sh
  REQARGS="-q $TEMPLATE -p 0-17"
  ```
- optionally, if you don't want to explicitly pass which query template should be used, create the default one named `qry_default.erb` in the `templates` directory  
  several ways are possible for doing so: create your own, copy an existing one and edit it, symlink or hardlink your favorite, ...
  ```bash
  ln -s qry_jira.erb templates/qry_default.erb
  ```
- initially clone the endoflife.date GitHub repository:
  ```bash
  git clone https://github.com/endoflife-date/release-data.git
  ```

# CALLBACKS

`updatewatch` has the ability to read the JSON replies from your ticketing system informing about the tasks created (in a `update.sh` run), render them through a template (using `generate_callback.rb`) to forge any desired summary text and submit this result to a callback URL (as `POST` request). This can be used to send a summary-eMail, pop up an alert in your monitoring system or drop a chat message to notify about the new tickets.

`update.sh` always uses this mechanism to print a text summary to CLI (using `CSTYLE=bash`); posting a (different) callback message to any URL is optional though.  
To activate this feature configure the following in your `settings` file:
```bash
# the parser template to use for reading JSON replies
# defaults to 'jira'
TEMPLATE=youtrack

# access/bearer token required to POST to URL
CTOKEN=1234567890abcdefghijklmnopqrstuvwxyz1234567890

# callback URL
CALLBACK=https://chatsystem.company.org/some/api/endpoint

# callback style for forging the POST request
# ERB file read is: templates/callback_$TEMPLATE-$CSTYLE.erb
CSTYLE=nextcloud_compact

# optional base path for tickets
# if defined baseurl="$THOST$TBASE" is passed to the ERB template
# this can be used to link the newly created tickets in a markdown message e.g.
TBASE=/issue
```

# USAGE

## `config.yaml`

`config.yaml` is the main configuration file; it contains the data sets which define your considered tools.

Basic format is
```yaml
---
toolname1:
  field1: value1
  field2: value2

toolname2:
  field1: value1
  field2: value2
```
where the "tool name" is a speaking name to be used in various places and the fields are the relevant attributes.  
What a "valid" field is mostly depends on the query template used and on the scripts below; so it varies depending on the context. The file/fields/format/... intentionally is not checked for correctness or integrity; this gives query template design a great flexibility.

Some practical examples:
```yaml
---
# YAML aliases are allowed
DEFAULTS:
  description: &descr A default description text to be used in the ticket.

# tool name is flexible
# we don't want to repeat ourself on the description
# and we paste this url into the ticket too
Apache httpd:
  file: release-data/releases/apache-http-server.json
  description: *descr
  url: https://httpd.apache.org/

# we're only interested in MySQL 8.0 updates (filter regex is matched against the version)
# and don't want a url here
MySQL:
  file: release-data/releases/mysql.json
  description: *descr
  filter: '^8\.0\.'

# but for Redis we care about several releases (positive regex match)
Redis:
  file: release-data/releases/redis.json
  description: rEdIs FTW!
  url: https://redis.io/docs/latest/operate/rs/release-notes/
  filter:
    - '^6\.2\.'
    - '^7\.2\.'
    - '^7\.4\.'

# no source file definition
# rather a template for manual interaction; not considered by generate_changerequest.rb e.g.
TP-Link SG3428X v1.30:
  description: *descr
  url: https://support.omadanetworks.com/en/product/sg3428x/v1.30/?resourceType=download

# maybe some people like empty tickets to save some bytes
WordPress:
  file: release-data/releases/wordpress.json

# GitHub release feed
Puppet Labs stdlib:
  file: feed-data/github.com_puppetlabs_puppetlabs-stdlib.json
  feed: https://github.com/puppetlabs/puppetlabs-stdlib/releases.atom
  description: *descr
```

## `field_getter.rb`

`field_getter.rb` is a small helper script to read the YAML config file and extract a single field from all configured data sets; it's mostly useful for the bash script(s) to make looping over things possible but you might find other use cases as well.

```bash
# defaults: config=config.yaml field=file
./field_getter.rb [config] [field]
```

## `feed_transformer.rb`

`feed_transformer.rb` is the script to fetch a GitHub release feed and write it to disk in the format that `generate_changerequest.rb` understands.  
Note that `feed_transformer.rb` solely creates a new source file to be fed to `generate_changerequest.rb` (in exactly the same way as the endoflife.date files) and does not trigger any further actions. It's just another chain link (e.g. for `update.sh`).  
Also note that feed fetching/parsing/transformation is intentionally done silently and without throwing errors. As feeds may be unavailable/unreachable temporarily, bailing out would break the whole update process unnecessarily.

```bash
# creates feed-data/github.com_puppetlabs_puppetlabs-stdlib.json
./feed_transformer.rb https://github.com/puppetlabs/puppetlabs-stdlib/releases.atom
```

## `generate_callback.rb`

`generate_callback.rb` is the helper script to read the JSON replies from a ticketing system and render them through a template to forge any desired result; it's mostly useful to generate the "tickets successfully created summary" for a callback but might find a different use as well.

The first parameter to the script is the callback template name. All successive parameters are JSON replies from one ticketing system; some kind of reply-splitting is done to make it possible to read "unseparated `curl` output" without pre-processing.  
If an environment variable `TBASEURL` exists it is passed to the template as `baseurl` (intended to create links in the style of `%{baseurl}/%{ticket}`).

```bash
# reads templates/callback_youtrack-bash.erb
# passes an array named 'results' to the template containing 5 hash-entries
./generate_callback.rb youtrack-bash '{"idReadable":"TEST-15","id":"3-27611","$type":"Issue"}' '{"idReadable":"TEST-16","id":"3-27612","$type":"Issue"}{"idReadable":"TEST-17","id":"3-27613","$type":"Issue"}' '{"idReadable":"TEST-18","id":"3-27614","$type":"Issue"}\n{"idReadable":"TEST-19","id":"3-27615","$type":"Issue"}'

# reads templates/callback_youtrack-nextcloud_verbose.erb
# passes an array named 'results' to the template containing 3 hash-entries
# passes 'baseurl' to the template as well
TBASEURL=https://tickets.company.org/issue ./generate_callback.rb youtrack-nextcloud_verbose '{"idReadable":"TEST-15","id":"3-27611","$type":"Issue","summary":"a new ticket"}' '{"idReadable":"TEST-16","id":"3-27612","$type":"Issue","summary":"another shiny ticket"} {"idReadable":"TEST-17","id":"3-27613","$type":"Issue","summary":"best ticket ever"}'
```

## `generate_request.rb`

`generate_request.rb` is the script to generate a `POST` request and submit it to the ticketing system using `curl` (e.g.).  
It reads the data for the specified tool (`[-t|--tool]`) from the YAML config file (if available), optionally allows overriding/setting options/fields on the cli and uses the specified version (`[-v|--version]`) to create the JSON request data.

```bash
. defaults
. settings

./generate_request.rb --help

./generate_request.rb -t mytool -v 1.0 | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API"
./generate_request.rb -t MySQL -v 2025_01-rc1 -d | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API"
./generate_request.rb -t "Apache httpd" -v 2.6.1024 -d "new description and delete the url from config" -u | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API"
./generate_request.rb -t "Apache httpd" -v 2.8 -r | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API"
```

## `generate_changerequest.rb`

`generate_changerequest.rb` is the script to compare an updated release notification input data file with the previously handled one and generate the resulting (bulk) `POST` request(s) to be submitted to the ticketing system.  
It finds all tool definitions from the YAML config that are using this source file (`[-s|--source]`), applies the optionally defined filters, allows overriding/setting options/fields similar to `generate_request.rb` (but for all matching tools), decides whether one or more single or a bulk request is created and in general is pretty smart.  
Note that `generate_changerequest.rb` solely generates the request and neither handles updating the data sources nor backing up the file ("acknowledge that this file has been handled").  
If a source file appears the first time (so there is no diff that can be acquired) only the first applicable task/ticket is put into the request data. To avoid or change this behavior, in advance, copy the source file into the `tmp/` directory and optionally manipulate it to fit your needs.

```bash
. defaults
. settings

cd release-data/
git pull

./generate_changerequest.rb --help

# if the file has never been handled before
./generate_changerequest.rb -s release-data/releases/haproxy.json | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API"

# if the file was treated in the past and a bulk API endpoint exists
./generate_changerequest.rb -b -s release-data/releases/apache-http-server.json | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$APIBULK"
./generate_changerequest.rb -b -s release-data/releases/tomcat.json -d | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$APIBULK"
./generate_changerequest.rb -b -s release-data/releases/gitlab.json -d "special case emergency updates for all instances" -f | curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$APIBULK"

# if the file was treated in the past and no bulk API endpoint exists (produces single requests separated by NUL characters)
readarray -d '' -t REQUESTS < <(./generate_changerequest.rb -s release-data/releases/rocky-linux.json)
for request in "${REQUESTS[@]}"; do curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API" <<< "$request"; done

cp release-data/releases/{haproxy,apache-http-server,tomcat,gitlab,rocky-linux}.json tmp/
```

## `update.sh`

`update.sh` is *the* wrapper around the various jobs, scripts, tripping hazards and think-abouts; it's most likely the script you want to run in your daily business.  
It updates the data sources, generates and submits the requests for all configured tools (to the appropriate API endpoint), does error handling, backups successfully processed source files, triggers callbacks ...

Unless you need to take care about special things using the previously mentioned scripts manually, all you need is:
```bash
./update.sh
```

# DEVELOPMENT

Development happens on GitHub in the well known way (fork, PR, issue, etc.).  
Feel free to report problems, suggest improvements or drop new ideas.

# ACKNOWLEDGMENTS

- [endoflife.date](https://github.com/endoflife-date/)  
  Those absolutely great guys ignited the spark for this project and their work form the foundation for all of this.
- [markt.de GmbH & Co. KG](https://github.com/markt-de/)  
  A corporation that makes it possible to realize FLOSS software like this, even nowadays where so many companies out there solely focus on making money.

# TODO

- make the script(s) safely callable via absolute paths
