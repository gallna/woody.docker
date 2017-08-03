# Logspout

| account   | logspout-url |
| ---       | --- |
| app.live: | http://lb.logspout.app.live.carsnip.com:8000 |
| dev:      | - |

## Logstash configuration:

- [Logspout grok pattern]https://nathanleclaire.com/blog/2015/04/27/automating-docker-logging-elasticsearch-logstash-kibana-and-logspout/
- [Logstash syslog message filter]https://gist.github.com/ollyg/2959887
- [Logstash syslog message filter]http://www.vmdoh.com/blog/centralizing-logs-lumberjack-logstash-and-elasticsearch
- [Setting up Logstash rfc5424 log template] https://techpunch.co.uk/development/how-to-ship-logs-with-rsyslog-and-logstash
- [Use container labels in logspout]https://github.com/gliderlabs/logspout/issues/163

## Inspect log streams using curl

Using the httpstream module, you can connect with curl to see your local aggregated logs in realtime. You can do this without setting up a route URI.

## Create custom routes via HTTP

Using the routesapi module logspout can also expose a /routes resource to create and manage routes.

```
$ curl <logspout-url>/routes \
    -X POST \
    -d '{"source": {"filter": "db", "types": ["stderr"]}, "target": {"type": "syslog", "addr": "logs.papertrailapp.com:55555"}}'
```

- `GET /logs` Display logs in realtime
- `GET /routes` List routes
- `POST /routes` Create a route
- `GET /routes/<id>` View a route
- `DELETE /routes/<id>` Delete a route

**Complete body template:**

```js
{
  "adapter": "syslog+tcp",
  "addr": "logstash:5000",
  "filter": "db",
  "filter_id": "container-id",
  "filter_name": "container name",
  "filter_labels": ["required.label.*", "com.example.foo:bar*"],
  "filter_sources": ["stdout", "stderr"],
  "options": {
    "append_tag": ".db"
}
```

**Filter-out system (rancher) services**

```js
{
    "address": "logstash:5000",
    "adapter": "syslog+tcp",
    "filter_labels": ["environment-tier:backend"],
    "options": {
      "append_tag": ".backend"
    }
}
```

# Container Labels:

- io.rancher.service.deployment.unit=f688d990-df88-4f61-982e-66c9e750c6a6,
- io.rancher.service.hash=60e616c046352cafdae7ef16f0f9f69e73f15b9d,
- io.rancher.stack_service.name=search-text-matching-service/search-text-matching-service
- io.rancher.container.name=search-text-matching-service-search-text-matching-service-1,
- io.rancher.container.ip=10.42.194.66/16,
- io.rancher.container.uuid=7e733991-272e-4873-afea-0112fb7430fd,
- io.rancher.project.name=search-text-matching-service,
- io.rancher.project_service.name=search-text-matching-service/search-text-matching-service,
- io.rancher.service.launch.config=io.rancher.service.primary.launch.config,
- io.rancher.stack.name=search-text-matching-service,
- io.rancher.cni.network=ipsec,
- io.rancher.cni.wait=true,
- environment-tier=backend,

**Container labels example:**

`docker ps --format "table {{.ID}}\t{{.Labels}}"`
```
CONTAINER ID        LABELS
949175b6034e        io.rancher.container.ip=10.42.4.221/16,io.rancher.project.name=logspout,io.rancher.service.deployment.unit=ed5836e0-8479-47d5-80b2-9f3cdad539a3,io.rancher.stack.name=logspout,io.rancher.cni.wait=true,io.rancher.container.name=logspout-logspout-4,io.rancher.container.uuid=1c020ec7-47fb-44fb-ad28-f272f9dae271,io.rancher.project_service.name=logspout/logspout,io.rancher.scheduler.global=true,io.rancher.service.launch.config=io.rancher.service.primary.launch.config,io.rancher.service.requested.host.id=28,io.rancher.stack_service.name=logspout/logspout,io.rancher.cni.network=ipsec
0e9d434e4cc5
```

**Syslog line example:**

```
<11>1 2017-02-03T12:42:05Z 418d883cf81f ipsec 11777 - [project="ipsec" stack="ipsec" ip=""] time="2017-02-03T12:42:05Z" level=debug msg="Sending arp reply for 10.42.138.137"
<14>1 2017-02-03T12:42:06Z 1720a5e41a53 car-indexer-es2 5712 - [project="car-indexer-es2" stack="car-indexer-es2" ip="10.42.49.106/16"] {"@timestamp":"2017-02-03T12:42:06.274+00:00","@version":1,"message":"Advert Processed","logger_name":"com.carsnip.resource.process.CarIndexer","thread_name":"pool-1-thread-1","level":"INFO","level_value":20000,"result":"ADVERT-UPDATED"}
<14>1 2017-02-03T12:42:06Z 418d883cf81f ipsec 11777 - [project="ipsec"" stack=""ipsec" ip=""] 11[KNL]  176: 1D 5C 1B 04 00 00 00 00 A2 38 01 00 00 00 00 00  .\.......8......
```

**Logstash entry example:**

**rfc5424 format**
```
{
     "container" => "consul",
          "proc" => "28020",
         "stack" => "consul",
        "format" => "rfc5424",
       "project" => "consul",
       "message" => "2017/02/03 16:22:19 [INFO] agent: Synced service 'ip-10-7-124-63:r-prometheus-prometheus-1-b182ffe4:9090'",
          "type" => "syslog",
      "priority" => "14",
      "hostname" => "ip-10-7-124-63",
    "@timestamp" => 2017-02-03T16:22:19.019Z,
          "port" => 60422,
      "@version" => "1",
          "host" => "ip-10-7-124-63",
     "timestamp" => "2017-02-03T16:22:19Z"
}
```

**json format**

```
{
     "container" => "car-indexer-es2",
          "proc" => "5712",
         "stack" => "car-indexer-es2",
           "log" => {
             "result" => "ADVERT-UPDATED",
         "@timestamp" => "2017-02-03T16:22:26.979+00:00",
              "level" => "INFO",
        "thread_name" => "pool-1-thread-1",
        "level_value" => 20000,
           "@version" => 1,
        "logger_name" => "com.carsnip.resource.process.CarIndexer",
            "message" => "Advert Processed"
    },
            "ip" => "10.42.49.106/16",
        "format" => "json",
       "project" => "car-indexer-es2",
          "type" => "syslog",
      "priority" => "14",
      "hostname" => "1720a5e41a53",
    "@timestamp" => 2017-02-03T16:22:26.980Z,
          "port" => 38278,
      "@version" => "1",
          "host" => "1720a5e41a53",
     "timestamp" => "2017-02-03T16:22:26Z"
}
```
