#!/bin/bash

# Usage:   ./structured-data.sh <key>=<label> [<key>=<label> ...]

# Example:
# $ ./structured-data.sh stack=io.rancher.stack.name project=io.rancher.project.name
#
# To get Labels:
# $ docker inspect fb50ee269e6b | jq -r '.[].Config.Labels | reduce to_entries[] as $item (""; . + $item.key + "=" + $item.value + "\n")'
# > io.rancher.container.ip=1.2.3.4
# > io.rancher.project.name=some-project
# > io.rancher.stack.name=some-stack-name

for key in "$@"; do
  IFS="=" read key value <<< "$key"
  printf '%s="{{ index .Container.Config.Labels "%s" }}"\n' "${key}" "${value}"
done | paste -sd"" -

echo -n >&2 "SYSLOG_TAG: "
syslog_tag="'$(cat <<SySlOg_TaG | paste -sd '' | tee /dev/stderr
{{ with .Container.Config.Labels }}
{{ index . "io.kubernetes.pod.name" }}{{ index . "io.rancher.project.name" }}
{{ end }}
SySlOg_TaG
)'"

echo -n >&2 "SYSLOG_STRUCTURED_DATA: "
structured_data="'$(cat <<SySlOg_StRuCtUrEd_DaTa | paste -sd '' | tee /dev/stderr
labels="{{ with index .Container.Config.Labels }}{{ . }}{{ end }}"
 hostname="{{ .Container.Config.Hostname }}"
{{ with .Container.Config.Labels }}
 container="{{ index . "io.kubernetes.container.name" }}{{ index . "io.rancher.container.name" }}"
 project="{{ index . "io.kubernetes.pod.name" }}{{ index . "io.rancher.project.name" }}"
 stack="{{ index . "io.kubernetes.pod.namespace" }}{{ index . "io.rancher.stack.name" }}"
 ip="{{ index . "io.rancher.container.ip" }}"
{{ end }}
SySlOg_StRuCtUrEd_DaTa
)'"

sed -i "s/SYSLOG_TAG:.*/SYSLOG_TAG: ${syslog_tag}/" $(dirname $0)/docker-compose.yml
sed -i "s/SYSLOG_STRUCTURED_DATA:.*/SYSLOG_STRUCTURED_DATA: ${structured_data}/" $(dirname $0)/docker-compose.yml

echo >&2;
grok=$(cat <<GrOk | paste -sd '' | tee /dev/stderr
<%{NONNEGINT:syslog5424_pri}>%{NONNEGINT:syslog5424_ver}
 +(?:%{TIMESTAMP_ISO8601:syslog5424_ts}|-)
 +(?:%{HOSTNAME:syslog5424_host}|-)
 +(?<syslog5424_app>-|[!-~]+)
 +(?<syslog5424_proc>-|[!-~]+)
 +(?<syslog5424_msgid>-|[!-~]+)
 +(?:\[labels=\"%{DATA:sd_labels}\"
 hostname=\"%{DATA:sd_hostname}\"
 container=\"%{DATA:sd_container}\"
 project=\"%{DATA:sd_project}\"
 stack=\"%{DATA:sd_stack}\"
 ip=\"%{DATA:sd_ip}\"
\]+)(%{GREEDYDATA:msg})
GrOk
)
echo >&2;

# logstash-regex
regex=$(cat <<GrOk | paste -sd '' | tee /dev/stderr
<(?<syslog5424_pri>\d+)>(?<syslog5424_ver>\d+)
\s(?<datetime>[\d-]+T[\d:]+\w)
\s(?<syslog5424_host>[^ ]+)
\s(?<syslog5424_app>[^ ]+)
\s(?<syslog5424_proc>[^ ]+)
\s(?<syslog5424_msgid>[^ ]+)
\s(?:\[hostname="(?<sd_hostname>[^"]*)"
\scontainer="(?<sd_container>[^"]*)"
\sproject="(?<sd_project>[^"]*)"
\sstack="(?<sd_stack>[^"]*)"
\sip="(?<sd_ip>[^"]*)"
\]+)\s(?<msg>.*)
GrOk
)
regex=$(cat <<GrOk | paste -sd '' | tee /dev/stderr
<(?<syslog3164_pri>\d+)>(?<datetime>[\w]+ [\d]+ [\d:]+)
\s(?<syslog3164_host>[^ ]+)
\s(?<syslog3164_app>[^ ]+)\[(?<syslog3164_proc>[^ ]+)\]:
\s(?<msg>.*)
GrOk
)

# \s(?:(?<year>\d+)-(?<month>\d+)-(?<day>\d+)T(?<hour>\d+):(?<minute>\d+):(?<sec>\d+)Z)
# <(?<a>\d+)>(?<b>\d+) +(?<c>[\d-ZT]+):(?<d>[\d:Z]+)\s(?<e>[^ ]+)\s(?<f>[^ ]+)\s(?<g>[^ ]+)\s(?<h>[^ ]+)\s(?:\[hostname="(?<hostname>[^"]*)" container="(?<container>[^"]*)" project="(?<project>[^"]*)" stack="(?<stack>[^"]*)" ip="(?<ip>[^"]*)"\])
# <(?<a>\d+)>(?<b>\d+)\s(?<c>[\d-ZT]+):(?<d>[\d:Z]+)\s(?<syslog5424_host>[^ ]+)\s(?<syslog5424_app>[^ ]+)\s(?<syslog5424_proc>[^ ]+)\s(?<syslog5424_msgid>[^ ]+)\s\[hostname="(?<hostname>[^"]+)"\scontainer="(?<container>[^"]+)"\sproject="(?<project>[^"]*)"\sstack="(?<stack>[^"]*)"\sip="(?<ip>[^"]*)"\]\s(?<msg>.*)

# "Labels": {
#     "io.kubernetes.container.hash": "367cb680",
#     "io.kubernetes.container.name": "cassandra",
#     "io.kubernetes.container.ports": "[{\"name\":\"intra-node\",\"containerPort\":7000,\"protocol\":\"TCP\"},{\"name\":\"tls-intra-node\",\"containerPort\":7001,\"protocol\":\"TCP\"},{\"name\":\"jmx\",\"containerPort\":7199,\"protocol\":\"TCP\"},{\"name\":\"cql\",\"containerPort\":9042,\"protocol\":\"TCP\"},{\"name\":\"thrift\",\"containerPort\":9160,\"protocol\":\"TCP\"}]",
#     "io.kubernetes.container.restartCount": "0",
#     "io.kubernetes.container.terminationMessagePath": "/dev/termination-log",
#     "io.kubernetes.pod.name": "cassandra-hnf7z",
#     "io.kubernetes.pod.namespace": "cassandra",
#     "io.kubernetes.pod.terminationGracePeriod": "30",
#     "io.kubernetes.pod.uid": "6ff45dbb-670b-11e7-a244-02cc7a251390"
# }
# "Labels": {
#     "io.rancher.container.agent_id": "275682",
#     "io.rancher.container.agent_service.metadata": "true",
#     "io.rancher.container.create_agent": "true",
#     "io.rancher.container.mac_address": "02:3d:6f:75:c7:7b",
#     "io.rancher.container.name": "network-services-metadata-1",
#     "io.rancher.container.system": "true",
#     "io.rancher.container.uuid": "8bef9728-f38d-4f78-b4f3-a4d6b98c9190",
#     "io.rancher.project.name": "network-services",
#     "io.rancher.project_service.name": "network-services/metadata",
#     "io.rancher.scheduler.global": "true",
#     "io.rancher.service.deployment.unit": "17a15dc2-efd8-4bac-bf85-8b2681dafba0",
#     "io.rancher.service.hash": "5bc36b264d3ef3f02c4c02c3dab500771ef6bfb7",
#     "io.rancher.service.launch.config": "io.rancher.service.primary.launch.config",
#     "io.rancher.service.requested.host.id": "122",
#     "io.rancher.sidekicks": "dns",
#     "io.rancher.stack.name": "network-services",
#     "io.rancher.stack_service.name": "network-services/metadata"
# }

# rancher-agent
# "Labels": {
#     "io.rancher.container.system": "rancher-agent"
# },
